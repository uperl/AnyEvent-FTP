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

=head1 ATTRIBUTES

=head2 $test_server-E<gt>test_uri

=cut

has test_uri => (
  is       => 'ro',
  required => 1,
);

=head1 METHODS

=head2 create_ftpserver_ok ( [ $default_context, [ $message ] ] )

=cut

sub create_ftpserver_ok (;$$)
{
  my($context, $message) = @_;
  
  my $uri = URI->new("ftp://127.0.0.1");
  
  $context //= 'Full'; # FIXME change to ::Memory when available
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

sub import
{
  my $caller = caller;
  no strict 'refs';
  *{join '::', $caller, 'create_ftpserver_ok'} = \&create_ftpserver_ok;
  *{join '::', $caller, 'connect_ftpclient_ok'} = \&connect_ftpclient_ok;
}

1;

