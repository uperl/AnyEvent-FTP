package AnyEvent::FTP::Client;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use AnyEvent::Socket qw( tcp_connect );
use AnyEvent::Handle;
use Role::Tiny::With;
use Carp qw( croak );

# ABSTRACT: Simple asynchronous ftp client
# VERSION

with 'AnyEvent::FTP::Role::ResponseBuffer';

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = bless {
    ready     => 0, 
    connected => 0, 
    timeout   => 30,
    on_error  => $args->{on_error} // sub { warn shift },
    on_close  => $args->{on_close} // sub {},
    on_send   => $args->{on_send}  // sub {},
    buffer    => [],
  }, $class;
  
  $self->on_each_response(sub {
    $self->_process;
  });
  
  $self;
}

sub on_error
{
  my($self,$new_value) = @_;
  $self->{on_error} = $new_value // sub {};
  $self;
}

sub on_close
{
  my($self,$new_value) = @_;
  $self->{on_close} = $new_value // sub {};
  $self;
}

sub on_send
{
  my($self,$new_value) = @_;
  $self->{on_send} = $new_value // sub {};
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
    
    $self->{handle} = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        # FIXME handle errors
        my ($hdl, $fatal, $msg) = @_;
        $_[0]->destroy;
        delete $self->{handle};
        $self->{connected} = 0;
        $self->{ready} = 0;
        $self->{on_error}->($msg);
        $self->{on_close}->();
        $self->{buffer} = [];
      },
      on_eof   => sub {
        $self->{handle}->destroy;
        delete $self->{handle};
        $self->{connected} = 0;
        $self->{ready} = 0;
        $self->{on_close}->();
        $self->{buffer} = [];
      },
    );
    
    $self->on_next_response(sub {
      if(defined $uri)
      {
        $self->_send(USER => $uri->user)->cb(sub {
          my $res = shift->recv;
          return $cv->croak($res) unless $res->is_success;
          $self->_send(PASS => $uri->password)->cb(sub {
            my $res = shift->recv;
            return $cv->croak($res) unless $res->is_success;
            $self->_send(CWD => $uri->path)->cb(sub {
              my $res = shift->recv;
              return $cv->croak($res) unless $res->is_success;
              $cv->send($res);
            });
          });
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
  }, sub { $self->{timeout} };
  
  return $cv;
}

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
  $self->_pasv_fetch([RETR => $filename], $destination);
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
  my $inner_cv = $self->_pasv_fetch([$verb => $location], [line => $cb]);
  $inner_cv->cb(sub {
    my $res = eval { shift->recv };
    $cv->croak($@) if $@;
    $cv->send(\@lines);
  });
  $cv;
}

sub _pasv_fetch
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
  
  my $cv = AnyEvent->condvar;
  
  $self->_send('PASV')->cb(sub {
    my $res = shift->recv;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          $cv->croak("unable to connect to data port: $!");
          return
        }
        
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
      };
    }
    else
    { $cv->croak($res) }
  });
  
  return $cv;
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

sub cwd  { shift->_send_simple(CWD => @_) }
sub cdup { shift->_send_simple('CDUP') }
sub noop { shift->_send_simple('NOOP') }
sub syst { shift->_send_simple('SYST') }
sub type { shift->_send_simple(TYPE => @_) }

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
  
  my $save = $self->{on_close};
  $self->{on_close} = sub {
    if(defined $res && $res->code == 221)
    { $cv->send($res) }
    elsif(defined $res)
    { $cv->croak($res) }
    else
    { $cv->croak("did not receive QUIT response from server") }
    $save->();
    $self->{on_close} = $save;
  };
  
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
      $self->{on_send}->($cmd, $args);
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
