use strict;
use warnings;
use v5.10;
use Test::More tests => 6;
use AnyEvent::FTP::Client;
use FindBin ();
require "$FindBin::Bin/lib.pl";

my $client = AnyEvent::FTP::Client->new;

prep_client( $client );
our $config;

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;

do {
  my $res = eval { $client->stat->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  like $code, qr{^21[123]$}, 'code = ' . $code;
};

do {
  my $res = eval { $client->stat('/')->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  like $code, qr{^21[123]$}, 'code = ' . $code;
};

do {
  eval { $client->stat('bogus')->recv };
  my $res = $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  is $code, 450, 'code = 450';
};

$client->quit->recv;

