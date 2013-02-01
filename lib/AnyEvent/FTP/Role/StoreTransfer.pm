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
  
  my $handle = $self->handle($fh);
  
  return unless defined $destination;
  
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

sub convert_destination
{
  my($self, $destination) = @_;
  
  return unless defined $destination;
  return $destination if ref($destination) eq 'CODE';
  
  if(ref($destination) eq '')
  {
    open my $fh, '<', $destination;
    $self->on_close(sub { close $fh });
    return sub {
      local $/;
      <$fh>;
    };
  }
  elsif(ref($destination) eq 'SCALAR')
  {
    my $buffer = $$destination;
    return sub {
      my $tmp = $buffer;
      undef $buffer;
      $tmp;
    };
  }
  elsif(ref($destination) eq 'GLOB')
  {
    sub {
      # TODO: for big files, maybe
      # break this up into batches
      local $/;
      <$destination>;
    };
  }
  else
  {
    die 'bad destination type';
  }
}

1;
