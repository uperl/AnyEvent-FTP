package AnyEvent::FTP::Server::Context::FSRO;

use strict;
use warnings;
use 5.010;
use Moo;

extends 'AnyEvent::FTP::Server::Context::FSRW';

# ABSTRACT: FTP Server client context class with read-only access
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Server;
 
 my $server = AnyEvent::FTP::Server->new(
   default_context => 'AnyEvent::FTP::Server::Context::FSRO',
 );

=head1 DESCRIPTION

This class provides a context for L<AnyEvent::FTP::Server> which uses the
actual filesystem to provide storage.

=head1 SUPER CLASS

This class inherits from

L<AnyEvent::FTP::Server::Context::FSRW>

=head1 COMMANDS

In addition to the commands provided by the above user class,
this context provides these FTP commands:

=over 4

=item STOR

=cut

sub cmd_stor
{
  my($self, $con, $req) = @_;
  unless(defined $self->data)
  { $con->send_response(425 => 'Unable to build data connection') }
  else
  { $con->send_response(553 => "Permission denied") }
  $self->done;
}

=item APPE

=cut

*cmd_appe = \&cmd_stor;

=item STOU

=cut

*cmd_stou = \&cmd_stor;
1;

=back

=cut

