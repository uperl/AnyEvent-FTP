package AnyEvent::FTP::Transfer;

use strict;
use warnings;
use v5.10;
use AnyEvent;
use AnyEvent::Handle;
use Role::Tiny::With;

# ABSTRACT: Transfer class for asynchronous ftp client
# VERSION

# FIXME: implement ABOR

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( open ));

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  bless {
    cv          => $args->{cv} // AnyEvent->condvar,
    client      => $args->{client},
    remote_name => $args->{command}->[1],
  }, $class;
}

sub cb { shift->{cv}->cb(@_) }
sub ready { shift->{cv}->ready }
sub recv { shift->{cv}->recv }

sub handle
{
  my($self, $fh) = @_;
  
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
    # this avoids deep recursion exception error (usually
    # a warning) in example fput.pl when the buffer is 
    # small (1024 on my debian VM)
    autocork  => 1,
  );
  
  $self->emit(open => $handle);
  
  $handle;
}

sub remote_name { shift->{remote_name} }

1;
