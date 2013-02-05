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

1;
