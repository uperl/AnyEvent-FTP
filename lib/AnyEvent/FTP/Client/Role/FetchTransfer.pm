package AnyEvent::FTP::Client::Role::FetchTransfer;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Fetch transfer interface for AnyEvent::FTP objects
# VERSION

sub xfer
{
  my($self, $fh, $destination) = @_;
  
  my $handle = $self->handle($fh);

  return unless defined $destination;
  
  $handle->on_read(sub {
    $handle->push_read(sub {
      $destination->($_[0]{rbuf});
      $_[0]{rbuf} = '';
    });
  });
}

sub convert_destination
{
  my($self, $destination) = @_;
  
  return unless defined $destination;
  return $destination if ref($destination) eq 'CODE';
  
  if(ref($destination) eq 'SCALAR')
  {
    return sub {
      $$destination .= shift;
    };
  }
  elsif(ref($destination) eq 'GLOB')
  {
    return sub {
      print $destination shift;
    };
  }
  elsif(ref($destination) eq '')
  {
    open my $fh, '>', $destination;
    $self->on_close(sub { close $fh });
    return sub {
      print $fh shift;
    };
  }
  else
  {
    die 'unimplemented: ' . ref $destination;
  }
}

1;
