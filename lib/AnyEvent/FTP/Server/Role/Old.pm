package AnyEvent::FTP::Server::Role::Old;

use strict;
use warnings;
use 5.010;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Role for old archaic FTP server commands
# VERSION

=head1 SYNOPSIS

Create a context:

 package AnyEvent::FTP::Server::Context::MyContext;
 
 use Moo;
 
 extends 'AnyEvent::FTP::Server::Context';
 with 'AnyEvent::FTP::Server::Role::Old';
 
 1;

Use archaic FTP commands:

 % telnet localhost 39835
 Trying 127.0.0.1...
 Connected to localhost.
 Escape character is '^]'.
 220 aeftpd dev
 user foo
 331 Password required for foo
 pass bar
 230 User foo logged in
 allo
 202 No storage allocation necessary
 noop
 200 NOOP command successful
 syst
 215 UNIX Type: L8
 quit
 221 Goodbye
 Connection closed by foreign host.

=head1 DESCRIPTION

This role provides a bunch of FTP commands that don't really do
anything anymore, but some older clients might try to use anyway.
If you are writing a context, it is probably a good idea to
consume this role rather than implementing these useless commands
yourself.

=head1 ATTRIBUTES

=head2 syst

The string returned by the SYST command.  This is often
"UNIX Type: L8" even if the server isn't actually running
on UNIX.  That is also the default.

=cut

has syst => (
  is      => 'rw',
  lazy    => 1,
  default => sub { 'UNIX Type: L8' }
);

=head1 COMMANDS

=over 4

=item ALLO

=cut

sub help_allo { 'ALLO is not implemented (ignored)' }

sub cmd_allo
{
  my($self, $con, $req) = @_;
  $con->send_response(202 => 'No storage allocation necessary');
  $self->done;
}

=item NOOP

=cut

sub help_noop { 'NOOP' }

sub cmd_noop
{
  my($self, $con, $req) = @_;
  $con->send_response(200 => 'NOOP command successful');
  $self->done;
}

=item SYST

=cut

sub help_syst { 'SYST' }

sub cmd_syst
{
  my($self, $con, $req) = @_;
  $con->send_response(215 => $self->syst);
  $self->done;
}

1;

=back

=cut
