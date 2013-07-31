package AnyEvent::FTP::Server::UnambiguousResponseEncoder;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: Server response encoder that encodes responses so they cannot be confused
# VERSION

with 'AnyEvent::FTP::Server::Role::ResponseEncoder';

sub encode
{
  my $self = shift;
  
  my $code;
  my $message;
  
  if(ref $_[0])
  {
    $code = $_[0]->code;
    $message = $_[0]->message;
  }
  else
  {
    ($code, $message) = @_;
  }
  
  $message = [ $message ] unless ref($message) eq 'ARRAY';
  
  my $last = pop @$message;
  
  return join "\015\012", (map { "$code-$_" } @$message), "$code $last\015\012";
}

1;
