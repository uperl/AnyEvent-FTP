use strict;
use warnings;
use v5.10;
use Test::More tests => 5;
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
  my $res = eval { $client->cwd($config->{dir})->recv };
  isa_ok $res, 'AnyEvent::FTP::Response';
  is $res->code, 250, 'code = 250';
};

do {
  my $res = eval { $client->pwd->recv };
  isa_ok $res, 'AnyEvent::FTP::Response';
  is $res->get_dir, $config->{dir}, "dir = " . $config->{dir};
};

$client->quit->recv;

