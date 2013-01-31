package AnyEvent::FTP::Role::StoreTransfer;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Store transfer interface for AnyEvent::FTP objects
# VERSION

sub xfer
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

1;
