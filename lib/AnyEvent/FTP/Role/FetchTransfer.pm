package AnyEvent::FTP::Role::FetchTransfer;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Fetch transfer interface for AnyEvent::FTP objects
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

1;
