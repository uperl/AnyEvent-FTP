package AnyEvent::FTP::Server::Role::Type;

use strict;
use warnings;
use 5.010;
use Moo::Role;

# ABSTRACT: Type role for FTP server
# VERSION

=head1 SYNOPSIS

 package AnyEvent::FTP::Server::Context::MyContext;

 use Moo;
 extends 'AnyEvent::FTP::Server::Context';
 with 'AnyEvent::FTP::Server::Role::Type';

=head1 DESCRIPTION

This role provides an interface for the FTP C<TYPE> command.

=head1 ATTRIBUTES

=head2 type

 my $type = $context->type;
 $context->type('A');
 $context->type('I');

The current transfer type 'A' for ASCII and I for binary.

=cut

has type => (
  is      => 'rw',
  default => sub { 'A' },
);

=head1 COMMANDS

=over 4

=item TYPE

=back

=cut

sub help_type { 'TYPE <sp> type-code (A, I)' }

sub cmd_type
{
  my($self, $con, $req) = @_;

  my $type = uc $req->args;
  $type =~ s/^\s+//;
  $type =~ s/\s+$//;

  if($type eq 'A' || $type eq 'I')
  {
    $self->type($type);
    $con->send_response(200 => "Type set to $type");
  }
  else
  {
    $con->send_response(500 => "Type not understood");
  }

  $self->done;
}

# TODO: STRU MODE

1;
