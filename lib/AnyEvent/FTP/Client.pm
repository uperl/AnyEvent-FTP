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

__PACKAGE__->define_events(qw( error close send ));

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
  { require AnyEvent::FTP::Client::passive }
  else
  { require AnyEvent::FTP::Client::active }
  
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
        # FIXME handle errors
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
    
  # FIXME parameterize timeout
  }, sub { 
    $self->{timeout}
  };
  
  return $cv;
}

# TODO: implement ACCT
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
  my($self, $filename, $destination) = @_;
  $self->_fetch([RETR => $filename], $destination);
}

sub resume_retr
{
  my($self, $filename, $destination) = @_;
  croak "resume_retr only works with a SCALAR ref destination" unless ref($destination) eq 'SCALAR';
  $self->_fetch(
    [RETR => $filename], 
    $destination, 
    [REST => do { use bytes; length $$destination }],
  );
}

sub stor
{
  my($self, $filename, $destination) = @_;
  $self->_store([STOR => $filename], $destination);
}

# TODO: the server gives the name in the 1xx response
# immediately after sending STOU (not the 2xx response
# when it is done), so at the moment we are loosing
# the filename.  parse it out so we get it.
sub stou
{
  my($self, $filename, $destination) = @_;
  $self->_store([STOU => $filename], $destination);
}

# for this to work under ProFTPd: AllowStoreRestart off
sub appe
{
  my($self, $filename, $destination) = @_;
  $self->_store([APPE => $filename], $destination);
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
  my $cb = sub {
    my($handle, $line) = @_;
    $line =~ s/\015?\012//g;
    push @lines, $line;
  };
  my $cv = AnyEvent->condvar;
  my $inner_cv = $self->_fetch([$verb => $location], [line => $cb]);
  $inner_cv->cb(sub {
    my $res = eval { shift->recv };
    $cv->croak($@) if $@;
    $cv->send(\@lines);
  });
  $cv;
}

sub _fetch
{
  my $self = shift;
  my $cmd_pair = shift;
  my $destination = shift;
  
  if(ref($destination) eq 'SCALAR')
  {
    my $buffer = $destination;
    $destination = sub {
      $$buffer .= shift;
    };
  }
  elsif(ref($destination) eq 'GLOB')
  {
    my $fh = $destination;
    $destination = sub {
      print $fh shift;
    };
  }
  
  $self->{passive} 
  ? $self->_fetch_passive($cmd_pair, $destination, @_)
  : $self->_fetch_active($cmd_pair, $destination, @_);
}

sub _store
{
  my $self = shift;
  my $cmd_pair = shift;
  my $destination = shift;
  
  if(ref($destination) eq '')
  {
    my $buffer = $destination;
    $destination = sub {
      my $tmp = $buffer;
      undef $buffer;
      $tmp;
    };
  }
  elsif(ref($destination) eq 'SCALAR')
  {
    my $buffer = $$destination;
    $destination = sub {
      my $tmp = $buffer;
      undef $buffer;
      $tmp;
    };
  }
  else
  {
    # FIXME implement GLOB and CODE
    die 'IMPLEMENT';
  }
  
  $self->{passive}
  ? $self->_store_passive($cmd_pair, $destination, @_)
  : $self->_store_active($cmd_pair, $destination, @_);
}

sub _slurp_data
{
  my($self, $fh, $destination) = @_;

  my $handle;
  $handle = AnyEvent::Handle->new(
    fh => $fh,
    on_error => sub {
      my($hdl, $fatal, $msg) = @_;
      $_[0]->destroy;
    },
    on_eof => sub {
      $handle->destroy;
    },
  );
        
  if(ref($destination) eq 'ARRAY')
  {
    $handle->on_read(sub {
      $handle->push_read(@$destination);
    });
  }
  else
  {
    $handle->on_read(sub {
      $handle->push_read(sub {
        $destination->($_[0]{rbuf});
        $_[0]{rbuf} = '';
      });
    });
  }
}

sub _spew_data
{
  my($self, $fh, $destination) = @_;
  
  my $handle;
  $handle = AnyEvent::Handle->new(
    fh => $fh,
    on_error => sub {
      my($hdl, $fatal, $msg) = @_;
      $_[0]->destroy;
    },
    on_eof => sub {
      $handle->destroy;
    },
  );
  
  $handle->on_drain(sub {
    my $data = $destination->();
    if(defined $data)
    {
      $handle->push_write($data);
    }
    else
    {
      $handle->push_shutdown;
    }
  });
}

sub rename
{
  my($self, $from, $to) = @_;
  $self->push_command(
    [ RNFR => $from ],
    [ RNTO => $to   ],
  );
}

# FIXME: implement SITE CHMOD
# FIXME: implement ABOR
sub cwd  { shift->push_command([ CWD => @_  ] ) }
sub cdup { shift->push_command([ 'CDUP'     ] ) }
sub noop { shift->push_command([ 'NOOP'     ] ) }
sub allo { shift->push_command([ ALLO => @_ ] ) }
sub syst { shift->push_command([ 'SYST'     ] ) }
sub type { shift->push_command([ TYPE => @_ ] ) }
sub stru { shift->push_command([ 'STRU'     ] ) }
sub mode { shift->push_command([ 'MODE'     ] ) }
sub rest { shift->push_command([ REST => @_ ] ) }
sub mkd  { shift->push_command([ MKD => @_  ] ) }
sub rmd  { shift->push_command([ RMD => @_  ] ) }
sub stat { shift->push_command([ STAT => @_ ] ) }
sub help { shift->push_command([ HELP => @_ ] ) }
sub dele { shift->push_command([ DELE => @_ ] ) }
sub rnfr { shift->push_command([ RNFR => @_ ] ) }
sub rnto { shift->push_command([ RNTO => @_ ] ) }

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

1;
