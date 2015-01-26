package AnyEvent::FTP::Response;

use strict;
use warnings;
use 5.010;
use overload
  '""' => sub { shift->as_string },
  fallback => 1;

# ABSTRACT: Response class for asynchronous ftp client
# VERSION

=head1 DESCRIPTION

Instances of this class represent a FTP server response.

=cut

sub new
{
  my($class, $code, $message) = @_;
  $message = [ $message ] unless ref($message) eq 'ARRAY';
  bless { code => $code, message => $message }, $class;
}

=head1 ATTRIBUTES

=head2 $client-E<gt>code

Integer code for the message.  These can be categorized thus:

=over 4

=item 1xx

Positive preliminary reply

=item 2xx

Positive completion reply

=item 3xx

Positive intermediate reply

=item 4xx

Transient negative reply

=item 5xx

Permanent negative reply

=back

Generally C<4xx> and C<5xx> messages are errors, where as C<1xx>, C<3xx> are various states of
(at least so far) successful operations.  C<2xx> indicates a completely successful 
operation.

=cut

sub code           { shift->{code}            }

=head2 $res-E<gt>message

The human readable message returned from the server.  This is always a list reference,
even if the server only returned one line.

=cut

sub message        { shift->{message}         }

=head1 METHODS

=head2 $res-E<gt>is_success

True if the response does not represent an error condition (codes C<1xx>, C<2xx> or C<3xx>).

=cut

sub is_success     { shift->{code} !~ /^[45]/ }

=head2 $res-E<gt>is_preliminary

True if the response is a preliminary positive reply (code C<1xx>).

=cut

sub is_preliminary { shift->{code} =~ /^1/    }

=head2 $res-E<gt>as_string

Returns a string representation of the response.  This may not be exactly what was
returned by the server, but will include the code and at least part of the message in 
a human readable format.

You can also get this string by treating objects of this class as a string (using
it in a double quoted string, or by using string operators):

 print "$res";

is the same as

 print $res->as_string;

=cut

sub as_string
{
  my($self) = @_;
  sprintf "[%d] %s%s", $self->{code}, $self->{message}->[0], @{ $self->{message} } > 1 ? '...' : '';
}

1;
