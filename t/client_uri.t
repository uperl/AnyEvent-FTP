use strict;
use warnings;
use v5.10;
use Test::More;
use AnyEvent::FTP::Client;
use FindBin ();
use URI;
require "$FindBin::Bin/lib.pl";

plan skip_all => 'requires client and server on localhost' if $ENV{AEF_REMOTE};
plan tests => 12;

my $client = eval { AnyEvent::FTP::Client->new };
diag $@ if $@;
isa_ok $client, 'AnyEvent::FTP::Client';

our $config;

prep_client( $client );

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
