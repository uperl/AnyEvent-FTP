package AnyEvent::FTP::Client::Role::ListTransfer;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Fetch transfer interface for AnyEvent::FTP objects
# VERSION

sub xfer
{
  my($self, $fh, $local) = @_;
  
  my $handle = $self->handle($fh);

  $handle->on_read(sub {
    $handle->push_read(line => sub {
      my($handle, $line) = @_;
      $line =~ s/\015?\012//g;
      push @{ $local }, $line;
    });
  });
}

sub convert_local
{
  my($self, $local) = @_;
  return $local;
}

sub push_command
{
  my $self = shift;
  my $cv = $self->{client}->push_command(
    @_,
  );
  
  $self->on_eof(sub {
    $cv->cb(sub {
      my $res = eval { $cv->recv };
      my $err = $@;
      if($err) { $self->{cv}->croak($err) }
      else     { $self->{cv}->send($res) }
    });
  });
}

1;
