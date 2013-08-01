package Test::AnyEventFTPServer;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use URI;
use AnyEvent;
use Test::Builder::Module;

extends 'AnyEvent::FTP::Server';

# ABSTRACT: Test (non-blocking) ftp clients against a real FTP server
# VERSION

=head1 SYNOPSIS

 use Test::More test => 3;
 use Test::AnyEventFTPServer;
 
 my $server = create_ftpserver_ok;
 my $client = $server->connect_ftpclient_ok;
 $server->help_coverage_ok;

=head1 DESCRIPTION

This module makes it easy to test ftp clients against a real 
L<AnyEvent::FTP> FTP server.  The FTP server is non-blocking in
and does not C<fork>, so if you are testing a FTP client that
blocks then you will need to do it in a separate process.
L<AnyEvent::FTP::Client> is a client that doesn't block and so
is safe to use in testing against the server.

=head1 ATTRIBUTES

=head2 $test_server-E<gt>test_uri

The full URL (including host, port, username and password) of the
test ftp server.  This is returned as L<URI>.

=cut

has test_uri => (
  is       => 'ro',
  required => 1,
);

=head1 METHODS

=head2 create_ftpserver_ok ( [ $default_context, [ $message ] ] )

Create the FTP server with a random username and password
for logging in.  You can get the username/password from the
C<test_uri> attribute, or connect to the server using
L<AnyEvent::FTP::Client> automatically with the C<connect_ftpclient_ok>
method below.

=cut

sub create_ftpserver_ok (;$$)
{
  my($context, $message) = @_;
  
  my $uri = URI->new("ftp://127.0.0.1");
  
  $context //= 'Memory';
  $context = "AnyEvent::FTP::Server::Context::$context"
    unless $context =~ /::/;
  my $name = (split /::/, $context)[-1];
  
  my $user = join '', map { chr(ord('a') + int rand(26)) } (1..10);
  my $pass = join '', map { chr(ord('a') + int rand(26)) } (1..10);
  $uri->userinfo(join(':', $user, $pass));
  
  my $server;
  eval { 
    $server = Test::AnyEventFTPServer->new(
      default_context => $context,
      hostname        => '127.0.0.1',
      port            => undef,
      test_uri        => $uri,
    );
    
    if($ENV{AEF_DEBUG})
    {
      my $tb = Test::Builder::Module->builder;
      $server->on_connect(sub {
        my $con = shift;
        $tb->note("CONNECT");
        
        $con->on_request(sub {
          my $raw = shift;
          $tb->note("CLIENT: $raw");
        });
        
        $con->on_response(sub {
          my $raw = shift;
          $tb->note("SERVER: $raw");
        });
        
        $con->on_close(sub {
          $tb->note("DISCONNECT");
        });
      });
    }
    
    $server->on_connect(sub {
      shift->context->authenticator(sub {
        return $_[0] eq $user && $_[1] eq $pass;
      });
    });
    
    my $cv = AnyEvent->condvar;
    my $timer = AnyEvent->timer(
      after => 5,
      cb    => sub { $cv->croak("timeout creating ftp server") },
    );
    $server->on_bind(sub {
      $uri->port(shift);
      $cv->send;
    });
    $server->start;
    $cv->recv;
  };
  my $error = $@;
  
  $message //= "created FTP ($name) server at $uri";

  my $tb = Test::Builder::Module->builder;
  $tb->ok($error eq '', $message);
  $tb->diag($error) if $error;
  
  $server;
}

=head2 $test_server-E<gt>connect_ftpclient_ok( [ $message ] )

Connect to the FTP server, return the L<AnyEvent::FTP::Client>
object which can be used for testing.

=cut

sub connect_ftpclient_ok
{
  my($self, $message) = @_;
  my $client;
  eval {
    require AnyEvent::FTP::Client;
    $client = AnyEvent::FTP::Client->new;
    my $cv = AnyEvent->condvar;
    my $timer = AnyEvent->timer(
      after => 5,
      cb    => sub { $cv->croak("timeout connecting with ftp client") },
    );
    $client->connect($self->test_uri)->cb(sub { $cv->send });
    $cv->recv;
  };
  my $error = $@;
  
  $message //= "connected to FTP server at " . $self->test_uri;
  
  my $tb = Test::Builder::Module->builder;
  $tb->ok($error eq '', $message);
  $tb->diag($error) if $error;  
  
  $client;
}

=head2 $test_server-E<gt>help_coverage_ok( [ $context_class, [ $message ] )

Test that there is a C<help_*> method for each C<cmd_*> method in the
given context class (the server's default context class is used if
it isn't provided).  This can also be used to test help coverage of
context roles.

=cut

sub help_coverage_ok
{
  my($self, $class, $message) = @_;
  
  $class //= $self->default_context;
  
  my @missing;

  my $client;  
  eval {
    require AnyEvent::FTP::Client;
    $client = AnyEvent::FTP::Client->new;
    my $cv = AnyEvent->condvar;
    my $timer = AnyEvent->timer(
      after => 5,
      cb    => sub { $cv->croak("timeout connecting with ftp client") },
    );
    $client->connect($self->test_uri)->cb(sub { $cv->send });
    $cv->recv;
  };
  my $error = $@;
  
  my $count = 0;
  unless($error)
  {
    foreach my $cmd (map { uc $_ } grep s/^cmd_//,  eval qq{ use $class; keys \%${class}::;})
    {
      if((eval { $client->help($cmd)->recv } || $@)->code != 214)
      { push @missing, $cmd }
      $count++;
    }
  }

  $message //= "help coverage for $class";

  my $tb = Test::Builder::Module->builder;
  $tb->ok($error eq '' && @missing == 0, $message);
  $tb->diag($error) if $error;
  $tb->diag("commands missing help: @missing") if @missing; 
  $tb->diag("didn't find ANY commands for class: $class")
    if $count == 0;

  return $self;
}

sub import
{
  my $caller = caller;
  no strict 'refs';
  *{join '::', $caller, 'create_ftpserver_ok'} = \&create_ftpserver_ok;
}

BEGIN { eval 'use EV' }

1;

