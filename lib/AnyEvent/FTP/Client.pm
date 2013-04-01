package AnyEvent::FTP::Client;

use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use AnyEvent;
use AnyEvent::Socket qw( tcp_connect );
use AnyEvent::Handle;
use Carp qw( croak );
use Socket qw( unpack_sockaddr_in inet_ntoa );

# ABSTRACT: Simple asynchronous ftp client
# VERSION

with 'AnyEvent::FTP::Role::Event';
with 'AnyEvent::FTP::Client::Role::ResponseBuffer';
with 'AnyEvent::FTP::Client::Role::RequestBuffer';

__PACKAGE__->define_events(qw( error close send greeting ));

has _connected => (
  is       => 'rw',
  default  => sub { 0 },
  init_arg => undef,
);

has timeout => (
  is      => 'rw',
  default => sub { 30 },
);

has passive => (
  is      => 'ro',
  default => sub { 1 },
);

foreach my $xfer (qw( Store Fetch List ))
{
  my $cb = sub {
    return shift->passive
    ? 'AnyEvent::FTP::Client::Transfer::Passive::'.$xfer
    : 'AnyEvent::FTP::Client::Transfer::Active::'.$xfer;
  };
  has '_'.lc($xfer) => ( is => 'ro', lazy => 1, default => $cb, init_arg => undef ),
}

sub BUILD
{
  my($self) = @_;
  $self->on_error(sub { warn shift });
  $self->on_close(sub {
    $self->clear_command;
    $self->_connected(0);
    delete $self->{handle};
  });
  
  require ($self->passive
    ? 'AnyEvent/FTP/Client/Transfer/Passive.pm'
    : 'AnyEvent/FTP/Client/Transfer/Active.pm');
  
  return;
}

sub connect
{
  my($self, $host, $port) = @_;
  
  if($host =~ /^ftp:/)
  {
    require URI;
    $host = URI->new($host);
  }
  
  my $uri;
  
  if(ref($host) && eval { $host->isa('URI') })
  {
    $uri = $host;
    $host = $uri->host;
    $port = $uri->port;
  }
  else
  {
    $port //= 21;
  }
  
  croak "Tried to reconnect while connected" if $self->_connected;
  
  my $cv = AnyEvent->condvar;
  $self->_connected(1);
  
  tcp_connect $host, $port, sub {
    my($fh) = @_;
    unless($fh)
    {
      $cv->croak("unable to connect: $!");
      $self->_connected(0);
      $self->clear_command;
      return;
    }
    
    # Get the IP address we are sending from for when
    # we use the PORT command (passive=0).
    $self->{my_ip} = do {
      my($port, $addr) = unpack_sockaddr_in getsockname $fh;
      inet_ntoa $addr;
    };
    
    $self->{handle} = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        my ($hdl, $fatal, $msg) = @_;
        $_[0]->destroy;
        $self->emit('error', $msg);
        $self->emit('close');
      },
      on_eof   => sub {
        $self->{handle}->destroy;
        $self->emit('close');
      },
    );
    
    $self->on_next_response(sub {
      my $res = shift;
      return $cv->croak($res) unless $res->is_success;
      $self->emit(greeting => $res);
      if(defined $uri)
      {
        my @start_commands = (
          [USER => $uri->user],
          [PASS => $uri->password],
        );
        push @start_commands, [CWD => $uri->path] if $uri->path ne '';
        $self->unshift_command(@start_commands, $cv);
      }
      else
      {
        $cv->send($res);
        $self->pop_command;
      }
    });
    
    $self->{handle}->on_read(sub {
      $self->{handle}->push_read( line => sub {
        my($handle, $line) = @_;
        $self->process_message_line($line);
      });
    });
    
  }, sub { 
    $self->timeout;
  };
  
  return $cv;
}

sub login
{
  my($self, $user, $pass) = @_;
  $self->push_command(
    [ USER => $user ],
    [ PASS => $pass ]
  );
}

sub retr
{
  my($self, $filename, $local) = (shift, shift, shift);
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  $self->_fetch->new({
    command     => [ RETR => $filename ],
    local       => $local,
    client      => $self,
    restart     => $args->{restart},
  });
}

sub stor
{
  my($self, $filename, $local) = @_;
  $self->_store->new(
    command     => [STOR => $filename],
    local       => $local,
    client      => $self,
  );
}

sub stou
{
  my($self, $filename, $local) = @_;
  my $xfer;
  my $cb = sub {
    my $name = shift->get_file;
    $xfer->{remote_name} = $name if defined $name;
    return;
  };
  $xfer = $self->_store->new(
    command     => [STOU => $filename, $cb],
    local       => $local,
    client      => $self,
  );
}

# for this to work under ProFTPd: AllowStoreRestart off
sub appe
{
  my($self, $filename, $local) = @_;
  $self->_store->new(
    command     => [APPE => $filename],
    local       => $local,
    client      => $self,
  );
}

sub nlst
{
  my($self, $location) = @_;
  $self->list($location, 'NLST');
}

sub list
{
  my($self, $location, $verb) = @_;
  $verb //= 'LIST';
  my @lines;
  my $cv = AnyEvent->condvar;
  $self->_list->new(
    command     => [ $verb => $location ],
    local       => \@lines,
    client      => $self,
  )->cb(sub {
    my $res = eval { shift->recv };
    $cv->croak($@) if $@;
    $cv->send(\@lines);
  });
  $cv;
}

sub rename
{
  my($self, $from, $to) = @_;
  $self->push_command(
    [ RNFR => $from ],
    [ RNTO => $to   ],
  );
}

(eval sprintf('sub %s { shift->push_command([ %s => @_])};1', lc $_, $_)) // die $@ 
  for qw( CWD CDUP NOOP ALLO SYST TYPE STRU MODE REST MKD RMD STAT HELP DELE RNFR RNTO USER PASS ACCT );

sub pwd
{
  my($self) = @_;
  my $cv = AnyEvent->condvar;
  $self->push_command(['PWD'])->cb(sub {
    my $res = eval { shift->recv } // $@;
    my $dir = $res->get_dir;
    if($dir) { $cv->send($dir) } 
    else { $cv->croak($res) }
  });
  $cv;
}

sub quit
{
  my($self) = @_;
  my $cv = AnyEvent->condvar;
  
  my $res;
  
  $self->push_command(['QUIT'])->cb(sub {
    $res = eval { shift->recv } // $@;
  });
  
  my $save = $self->{event}->{close};
  $self->{event}->{close} = [ sub {
    if(defined $res && $res->is_success)
    { $cv->send($res) }
    elsif(defined $res)
    { $cv->croak($res) }
    else
    { $cv->croak("did not receive QUIT response from server") }
    $_->() for @$save;
    $self->{event}->{close} = $save;
  } ];
  
  return $cv;
}

sub site
{
  require AnyEvent::FTP::Client::Site;
  AnyEvent::FTP::Client::Site->new(shift);
}

1;
