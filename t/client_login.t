use strict;
use warnings;
use v5.10;
use Test::More tests => 6;
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

my $res = eval { $client->login($config->{user}, $config->{pass})->recv };
diag $@ if $@;
isa_ok $res, 'AnyEvent::FTP::Response';

is $res->code, 230, 'code = 230';

is eval { $client->quit->recv->code }, 221, 'code = 221';
diag $@ if $@;

$client->connect($config->{host}, $config->{port})->recv;

eval { $client->login('bogus', 'bogus')->recv };
my $error = $@;
isa_ok $error, 'AnyEvent::FTP::Response';
is $error->code, 530, 'code = 530';