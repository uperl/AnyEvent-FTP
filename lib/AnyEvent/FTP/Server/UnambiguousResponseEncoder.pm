package AnyEvent::FTP::Server::UnambiguousResponseEncoder;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: Server response encoder that encodes responses so they cannot be confused
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Server::UnambiguousResponseEncoder;
 my $encoder = AnyEvent::FTP::Server::UnambiguousResponseEncoder->new;
 # encode a FTP welcome message
 my $message = $encoder->encode(220, 'welcome to myftpd');

=head1 DESCRIPTION

Objects of this class are used to encode responses which are returned to
the client from the server.

=cut

with 'AnyEvent::FTP::Server::Role::ResponseEncoder';

=head1 METHODS

=head2 $encoder-E<gt>encode( [ $res | $code, $message ] )

Returns the encoded message.  You can pass in either a
L<AnyEvent::FTP::Response> object, or a code message pair.

=cut

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
