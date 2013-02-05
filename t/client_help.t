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
  my $res = eval { $client->help->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  like $code, qr{^21[14]$}, 'code = ' . $code;
};

do {
  my $res = eval { $client->help('help')->recv };
  diag $@ if $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  like $code, qr{^21[14]$}, 'code = ' . $code;
};

SKIP: {
  our $detect;
  skip 'pure-FTPd does not return [45]50 on bogus file', 2 if $detect->{pu};
  skip 'vsftp does not return 502 on bogus help', 2 if $detect->{vs};
  skip 'Net::FTPServer does not return 502 on bogus help', 2 if $detect->{pl};
  eval { $client->help('bogus')->recv };
  my $res = $@;
  isa_ok $res, 'AnyEvent::FTP::Response';
  my $code = eval { $res->code };
  diag $@ if $@;
  is $code, 502, 'code = ' . $code;
};

$client->quit->recv;

