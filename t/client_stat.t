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

SKIP: {
  our $detect;
  skip 'wu-ftpd does not return [45]50 on bogus file', 2 if $detect->{wu};
  skip 'pure-FTPd does not return [45]50 on bogus file', 2 if $detect->{pu};
  skip 'vsftp does not return [45]50 on bogus file', 2 if $detect->{vs};
  skip 'IIS does not return [45]50 on bogus file', 2 if $detect->{ms};
  eval { $client->stat('bogus')->recv };
  my $res = $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  like $code, qr{^[45]50$}, 'code = ' . $code;
};

$client->quit->recv;

