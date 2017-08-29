package AnyEvent::FTP::Request;

use strict;
use warnings;
use 5.010;
use overload '""' => sub { shift->as_string };

# ABSTRACT: Request class for asynchronous ftp server
# VERSION

=head1 DESCRIPTION

Instances of this class represent client requests.

=cut

sub new
{
  my($class, $cmd, $args, $raw) = @_;
  bless { command => $cmd, args => $args, raw => $raw }, $class;
}

=head1 ATTRIBUTES

=head2 command

 my $command = $req->command;

The command, usually something like C<USER>, C<PASS>, C<HELP>, etc.

=cut

sub command { shift->{command} }

=head2 args

 my $args = $res->args;

The arguments passed in with the command

=cut

sub args    { shift->{args}    }

=head2 raw

 my $raw = $res->raw;

The raw, unparsed request.

=cut

sub raw     { shift->{raw}     }

=head1 METHODS

=head2 as_string

 my $str = $res->as_string
 my $str = "$res";

Returns a string representation of the request.  This may not be exactly the same as
what was actually sent to the server (see C<raw> attribute for that).  You can also
call this by treating the object like a string (using string operators, or including
it in a double quoted string), so

 print "$req";

is the same as

 print $req->as_string;

=cut

sub as_string
{
  my $self = shift;
  join ' ', $self->command, $self->args;
}

1;
