package AnyEvent::FTP::Client;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use AnyEvent::Socket qw( tcp_connect );
use AnyEvent::Handle;
use Role::Tiny::With;
use Carp qw( croak );
use Socket qw( unpack_sockaddr_in inet_ntoa );

# ABSTRACT: Simple asynchronous ftp client
# VERSION

with 'AnyEvent::FTP::Role::Event';
with 'AnyEvent::FTP::Role::ResponseBuffer';
with 'AnyEvent::FTP::Role::RequestBuffer';

__PACKAGE__->define_events(qw( error close send greeting ));

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = bless {
    connected => 0, 
    timeout   => 30,
    passive   => $args->{passive}  // 1,
  }, $class;

  if($self->{passive})
  { 
    require AnyEvent::FTP::Transfer::Passive;
    $self->{store} = 'AnyEvent::FTP::Transfer::Passive::Store';
    $self->{fetch} = 'AnyEvent::FTP::Transfer::Passive::Fetch';
    $self->{list}  = 'AnyEvent::FTP::Transfer::Passive::List';
  }
  else
  {
    require AnyEvent::FTP::Transfer::Active;
    $self->{store} = 'AnyEvent::FTP::Transfer::Active::Store';
    $self->{fetch} = 'AnyEvent::FTP::Transfer::Active::Fetch';
    $self->{list}  = 'AnyEvent::FTP::Transfer::Active::List';
  }
  
  $self->on_error(sub { warn shift });
  $self->on_close(sub {
    $self->clear_command;
    $self->{connected} = 0;
    delete $self->{handle};
  });
  
  $self;
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
  
  croak "Tried to reconnect while connected" if $self->{connected};
  
  my $cv = AnyEvent->condvar;
  $self->{connected} = 1;
  
  tcp_connect $host, $port, sub {
    my($fh) = @_;
    unless($fh)
    {
      $cv->croak("unable to connect: $!");
      $self->{connected} = 0;
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
        $line =~ s/\015?\012//g;
        $self->process_message_line($line);
      });
    });
    
  }, sub { 
    $self->{timeout}
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
  my($self, $filename, $destination) = (shift, shift, shift);
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  $self->{fetch}->new({
    command     => [ RETR => $filename ],
    destination => $destination,
    client      => $self,
    restart     => $args->{restart},
  });
}

sub stor
{
  my($self, $filename, $destination) = @_;
  $self->{store}->new(
    command     => [STOR => $filename],
    destination => $destination,
    client      => $self,
  );
}

sub stou
{
  my($self, $filename, $destination) = @_;
  my $xfer;
  my $cb = sub {
    my $name = shift->get_file;
    $xfer->{remote_name} = $name if defined $name;
    return;
  };
  $xfer = $self->{store}->new(
    command     => [STOU => $filename, $cb],
    destination => $destination,
    client      => $self,
  );
}

# for this to work under ProFTPd: AllowStoreRestart off
sub appe
{
  my($self, $filename, $destination) = @_;
  $self->{store}->new(
    command     => [APPE => $filename],
    destination => $destination,
    client      => $self,
  );
}

sub nlst
{
  my($self, $location) = @_;
  $self->_list(NLST => $location);
}

sub list
{
  my($self, $location) = @_;
  $self->_list(LIST => $location);
}

sub _list
{
  my($self, $verb, $location) = @_;
  my @lines;
  my $cv = AnyEvent->condvar;
  $self->{list}->new(
    command     => [ $verb => $location ],
    destination => \@lines,
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
