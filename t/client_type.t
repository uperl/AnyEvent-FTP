use strict;
use warnings;
use v5.10;
use Test::More tests => 7;
use AnyEvent::FTP::Client;
use FindBin ();
require "$FindBin::Bin/lib.pl";

my $w = AnyEvent->timer( after => 5, cb => sub { say STDERR "TIMEOUT"; exit } );

my $client = eval { AnyEvent::FTP::Client->new };
diag $@ if $@;
isa_ok $client, 'AnyEvent::FTP::Client';

our $config;

$client->on_each_response(sub {
  #my $res = shift;
  #diag sprintf "[ %d ] %s\n", $res->code, $_ for @{ $res->message };
});

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;

do {
  my $res = eval { $client->type('I')->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  is eval { $res->code }, 200, 'code = 200';
  diag $@ if $@;
};

do {
  my $res = eval { $client->type('A')->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  is eval { $res->code }, 200, 'code = 200';
  diag $@ if $@;
};

do {
  eval { $client->type('X')->recv };
  my $error = $@;
  isa_ok $error, 'AnyEvent::FTP::Response';
  is eval { $error->code }, 500, 'code = 500';
  diag $@ if $@;
};

$client->quit->recv;

