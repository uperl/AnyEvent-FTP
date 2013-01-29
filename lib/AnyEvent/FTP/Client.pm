package AnyEvent::FTP::Client;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use AnyEvent::Socket qw( tcp_connect tcp_server );
use AnyEvent::Handle;
use Role::Tiny::With;
use Carp qw( croak );
use Socket qw( unpack_sockaddr_in inet_ntoa );

# ABSTRACT: Simple asynchronous ftp client
# VERSION

with 'AnyEvent::FTP::Role::Event';
with 'AnyEvent::FTP::Role::ResponseBuffer';

__PACKAGE__->define_events(qw( error close send ));

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = bless {
    ready     => 0, 
    connected => 0, 
    timeout   => 30,
    passive   => $args->{passive}  // 1,
    buffer    => [],
  }, $class;

  if($self->{passive})
  { require AnyEvent::FTP::Client::passive }
  else
  { require AnyEvent::FTP::Client::active }
  
  $self->on_error(sub { warn shift });
  
  $self->on_each_response(sub {
    $self->_process;
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
      $self->{ready} = 0;
      $self->{buffer} = [];
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
        delete $self->{handle};
        $self->{connected} = 0;
        $self->{ready} = 0;
        $self->emit('error', $msg);
        $self->emit('close');
        $self->{buffer} = [];
      },
      on_eof   => sub {
        $self->{handle}->destroy;
        delete $self->{handle};
        $self->{connected} = 0;
        $self->{ready} = 0;
        $self->emit('close');
        $self->{buffer} = [];
      },
    );
    
    $self->on_next_response(sub {
      if(defined $uri)
      {
        $self->login($uri->user, $uri->password)->cb(sub {
          my $res = eval { shift->recv };
          if(defined $res)
          {
            if($uri->path ne '')
            {
              $self->_send(CWD => $uri->path)->cb(sub {
                my $res = shift->recv;
                return $cv->croak($res) unless $res->is_success;
                $cv->send($res);
              });
            }
            else 
            { $cv->send($res) }
          }
          else
          { $cv->croak($@) }
        });
      }
      else
      {
        $cv->send(shift);
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

# FIXME: implement STOR, APPE, STOU, ALLO, MKD, RMD, DEL, rename (RNFR, RNTO)

# TODO: implement ACCT
sub login
{
  my($self, $user, $pass) = @_;
  
  my $cv = AnyEvent->condvar;
  
  $self->_send(USER => $user)->cb(sub {
    my $res = shift->recv;
    if($res->code == 331)
    {
      $self->_send(PASS => $pass)->cb(sub {
        my $res = shift->recv;
        if($res->code == 230)
        { $cv->send($res) }
        else
        { $cv->croak($res) }
      });
    }
    else
    { $cv->croak($res) }
  });
  
  return $cv;
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
  my $cv = AnyEvent->condvar;
  $self->_send(REST => do { use bytes; length $$destination })->cb(sub {
    my $res = shift->recv;
    if($res->is_success)
    {
      $self->_fetch([RETR => $filename], $destination)->cb(sub {
        my $res = eval { shift->recv };
        if($@) { $cv->croak($@) }
        else { $cv->send($res) }
      });
    }
    else
    { $cv->croak($res) }
  });
  $cv;
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
  my($self, $cmd_pair, $destination) = @_;
  
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
  ? $self->_fetch_passive($cmd_pair, $destination)
  : $self->_fetch_active($cmd_pair, $destination);
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

sub _slurp_cmd
{
  my($self, $cmd_pair, $cv) = @_;
  $self->_send(@$cmd_pair)->cb(sub {
    my $res = shift->recv;
    if($res->is_success)
    {
      $self->_wait->cb(sub {
        my $res = shift->recv;
        if($res->is_success)
        { $cv->send($res) }
        else
        { $cv->croak($res) }
      });
    }
    else
    { $cv->croak($res) }
  });
}

sub _send_simple
{
  my $self = shift;
  my $cv = AnyEvent->condvar;
  $self->_send(@_)->cb(sub {
    my $res = shift->recv;
    if($res->is_success)
    { $cv->send($res) }
    else
    { $cv->croak($res) }
  });
  return $cv;
}

# FIXME: implement STAT and HELP
# FIXME: implement SITE CHMOD
# FIXME: implement ABOR
sub cwd  { shift->_send_simple(CWD => @_) }
sub cdup { shift->_send_simple('CDUP') }
sub noop { shift->_send_simple('NOOP') }
sub syst { shift->_send_simple('SYST') }
sub type { shift->_send_simple(TYPE => @_) }
sub stru { shift->_send_simple('STRU') }
sub mode { shift->_send_simple('MODE') }
sub rest { shift->_send_simple(REST => @_) }

sub pwd
{
  my($self) = @_;
  my $cv = AnyEvent->condvar;
  $self->_send('PWD')->cb(sub {
    my $res = shift->recv;
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
  
  $self->_send('QUIT')->cb(sub {
    $res = shift->recv;
  });
  
  my $save = $self->{event}->{close};
  $self->{event}->{close} = [ sub {
    if(defined $res && $res->code == 221)
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

sub _send
{
  my($self, $cmd, $args) = @_;
  
  $self->_process if $self->{ready};
  
  my $cv = AnyEvent->condvar;
  push @{ $self->{buffer} }, [ $cmd, $args, $cv ];
  
  $self->_process if $self->{ready};

  return $cv;
}

sub _wait
{
  my($self) = @_;
  $self->_send(undef, undef);
}

sub _process
{
  my($self) = @_;
  if(@{ $self->{buffer} } > 0)
  {
    my($cmd, $args, $cv) = @{ shift @{ $self->{buffer} } };
    $self->on_next_response(sub { $cv->send(shift) });
    if(defined $cmd)
    {
      my $line = defined $args ? join(' ', $cmd, $args) : $cmd;
      $self->emit('send', $cmd, $args);
      $self->{handle}->push_write("$line\015\012");
    }
    $self->{ready} = 0;
  }
  else
  {
    $self->{ready} = 1;
  }
}

1;
