package AnyEvent::FTP::Server::Role::Auth;

use strict;
use warnings;
use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Authentication role for FTP server
# VERSION

=head1 SYNOPSIS

In your context:

 package AnyEvent::FTP::Server::Context::MyContext;
 
 use Moo;
 extends 'AnyEvent::FTP::Server::Context';
 with 'AnyEvent::FTP::Server::Role::Auth';
 
 has '+unauthenticated_safe_commands' => (
   default => sub { [ qw( USER PASS HELP QUIT FOO ) ] },
 );
 
 # this command is deemed safe pre auth by 
 # unauthenticated_safe_commands
 sub cmd_foo
 {
   my($self, $con, $req) = @_;
   $con->send_response(211 => 'Here to stay');
   $self->done;
 }
 
 # this command can pnly be executed after
 # authentication
 sub cmd_bar
 {
   my($self, $con, $req) = @_;
   $con->send_response(211 => 'And another thing');
   $self->done;
 }

Then when you create your server object:

 use AnyEvent:FTP::Server;
 
 my $server = AnyEvent::FTP::Server->new;
 $server->on_connect(sub {
   # $con isa AnyEvent::FTP::Server::Connection
   my $con = shift;
   # $context isa AnyEvent::FTP::Server::Context::MyContext
   my $context = $con->context;
   
   # allow login from user 'user' with password 'secret'
   $context->authenticator(sub {
     my($user, $pass) = @_;
     return $user eq 'user' && $pass eq 'secret';
   });
   
   # make the client wait 5 seconds if they enter a
   # bad username / password
   $context->bad_authentication_delay(5);
 });

=head1 DESCRIPTION

This role provides an authentication interface for your L<AnyEvent::FTP::Server>
context.

=head1 ATTRIBUTES

=head2 user

The user specified by the last FTP C<USER> command.

=cut

has user => (is => 'rw');

=head2 authenticated

True if the user has successfully logged in.

=cut

has authenticated => (is => 'rw', default => sub { 0 } );

=head2 authenticator

Sub ref used to check username password combinations.
By default all authentication requests are refused.

=cut

has authenticator => (
  is      => 'rw',
  lazy    => 1,
  default => sub { sub { 0 } },
);

=head2 bad_authentication_delay

Number of seconds to wait after a bad login attempt.

=cut

has bad_authentication_delay => (
  is      => 'rw',
  default => sub { 5 },
);

=head2 unauthenticated_safe_commands

List of the commands that are safe to execute before the user
has authenticated.  The default is USER, PASS, HELP and QUIT

=cut

has _safe_commands => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my %h = map { (lc $_ => 1) } @{ shift->unauthenticated_safe_commands };
    \%h;
  },
);

has unauthenticated_safe_commands => (
  is      => 'ro',
  lazy    => 1,
  default => sub { 
    [qw( USER PASS HELP QUIT )]
  },
);

=head1 METHODS

=head2 $context-E<gt>auth_command_check_hook

This hook checks that any commands executed by the client before
authentication are in the C<authenticated_safe_commands> list.

=cut

sub auth_command_check_hook
{
  my($self, $con, $command) = @_;
  return 1 if $self->authenticated || $self->_safe_commands->{$command};
  $con->send_response(530 => 'Please login with USER and PASS');
  $self->done;
  return 0;
}

=head1 COMMANDS

=over 4

=item USER

=cut

sub help_user { 'USER <sp> username' }

sub cmd_user
{
  my($self, $con, $req) = @_;
  
  my $user = $req->args;
  $user =~ s/^\s+//;
  $user =~ s/\s+$//;
  
  if($user ne '')
  {
    $self->user($user);
    $con->send_response(331 => "Password required for $user");
  }
  else
  {
    $con->send_response(530 => "USER requires a parameter");
  }
  
  $self->done;
}

=item PASS

=cut

sub help_pass { 'PASS <sp> password' }

sub cmd_pass
{
  my($self, $con, $req) = @_;
  
  my $user = $self->user;
  my $pass = $req->args;
  
  unless(defined $user)
  {
    $con->send_response(503 => 'Login with USER first');
    $self->done;
    return;
  }
  
  if($self->authenticator->($user, $pass))
  {
    $con->send_response(230 => "User $user logged in");
    $self->{authenticated} = 1;
    $self->emit(auth => $user);
    $self->done;
  }
  else
  {
    my $delay = $self->bad_authentication_delay;
    if($delay > 0)
    {
      my $timer;
      $timer = AnyEvent->timer( after => 5, cb => sub {
        $con->send_response(530 => 'Login incorrect');
        $self->done;
        undef $timer;
      });
    }
    else
    {
      $con->send_response(530 => 'Login incorrect');
      $self->done;
    }
  }
}

1;

=back

=cut
