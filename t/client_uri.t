use strict;
use warnings;
use v5.10;
use Test::More tests => 12;
use AnyEvent::FTP::Client;
use FindBin ();
use URI;
require "$FindBin::Bin/lib.pl";

my $w = AnyEvent->timer( after => 5, cb => sub { say STDERR "TIMEOUT"; exit } );

my $client = eval { AnyEvent::FTP::Client->new( on_send => sub { } ) };
diag $@ if $@;
isa_ok $client, 'AnyEvent::FTP::Client';

our $config;

$client->on_each_response(sub {
  #my $res = shift;
  #diag sprintf "[ %d ] %s\n", $res->code, $_ for @{ $res->message };
});

my $uri = URI->new('ftp:');
$uri->host($config->{host});
$uri->port($config->{port});
$uri->user($config->{user});
$uri->password($config->{pass});
$uri->path($config->{dir});
isa_ok $uri, 'URI';

do {
  my $res = eval { $client->connect($uri)->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  is $res->code, 250, 'code = 250';
  is $client->pwd->recv, $config->{dir}, "dir = " . $config->{dir};
  $client->quit->recv;
};

do {
  my $res = eval { $client->connect($uri->as_string)->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  is $res->code, 250, 'code = 250';
  is $client->pwd->recv, $config->{dir}, "dir = " . $config->{dir};
  $client->quit->recv;
};

$uri->user('bogus');
$uri->password('bogus');

do {
  eval { $client->connect($uri->as_string)->recv };
  my $error = $@;
  isa_ok $error, 'AnyEvent::FTP::Response';
  is $error->code, 530, 'code = 530';
  $client->quit->recv;
};

$uri->user($config->{user});
$uri->password($config->{pass});
$uri->path('/bogus/bogus/bogus');

do {
  eval { $client->connect($uri->as_string)->recv };
  my $error = $@;
  isa_ok $error, 'AnyEvent::FTP::Response';
  is $error->code, 550, 'code = 550';
  $client->quit->recv;
};
