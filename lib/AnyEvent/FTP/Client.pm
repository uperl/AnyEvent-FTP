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

sub connect
{
  my($self, $host, $port) = @_;
  
  croak "Tried to reconnect while connected" if $self->{connected};
  
  my $condvar = AnyEvent->condvar;
  $self->{connected} = 1;
  
  tcp_connect $host, $port, sub {
    my($fh) = @_;
    unless($fh)
    {
      $condvar->croak("unable to connect: $!");
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
      $condvar->send(shift);
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
  
  return $condvar;
}

sub login
{
  my($self, $user, $pass) = @_;
  
  my $condvar = AnyEvent->condvar;
  
  $self->_send(USER => $user)->cb(sub {
    my $res = shift->recv;
    if($res->code == 331)
    {
      $self->_send(PASS => $pass)->cb(sub {
        my $res = shift->recv;
        if($res->code == 230)
        { $condvar->send($res) }
        else
        { $condvar->croak($res) }
      });
    }
    else
    { $condvar->croak($res) }
  });
  
  return $condvar;
}

sub _send_simple
{
  my $self = shift;
  my $cv = AnyEvent->condvar;
  $self->_send(@_)->cb(sub {
    my $res = shift->recv;
    if($res->code =~ /^[45]/)
    { $cv->croak($res) }
    else
    { $cv->send($res) }
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
  my $condvar = AnyEvent->condvar;
  
  my $res;
  
  $self->_send('QUIT')->cb(sub {
    $res = shift->recv;
  });
  
  my $save = $self->{on_close};
  $self->{on_close} = sub {
    if(defined $res && $res->code == 221)
    { $condvar->send($res) }
    elsif(defined $res)
    { $condvar->croak($res) }
    else
    { $condvar->croak("did not receive QUIT response from server") }
    $save->();
    $self->{on_close} = $save;
  };
  
  return $condvar;
}

sub _send
{
  my($self, $cmd, $args) = @_;
  my $line = defined $args ? join(' ', $cmd, $args) : $cmd;
  
  my $condvar = AnyEvent->condvar;
  push @{ $self->{buffer} }, [ "$line\015\012", $condvar ];
  
  $self->_process if $self->{ready};

  return $condvar;
}

sub _process
{
  my($self) = @_;
  if(@{ $self->{buffer} } > 0)
  {
    my($line, $cv) = @{ shift @{ $self->{buffer} } };
    $self->on_next_response(sub { $cv->send(shift) });
    $self->{on_send}->($line);
    $self->{handle}->push_write($line);
    $self->{ready} = 0;
  }
  else
  {
    $self->{ready} = 1;
  }
}

1;
