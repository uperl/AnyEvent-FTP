use strict;
use warnings;
use v5.10;
use Test::More;
use AnyEvent::FTP::Client;
use FindBin ();
require "$FindBin::Bin/lib.pl";

my $client = AnyEvent::FTP::Client->new;

prep_client( $client );
our $config;

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;

our $detect;
plan skip_all => 'wu-ftpd does not support ALLO' if $detect->{wu};
plan skip_all => 'pure-ftpd does not support ALLO without arument' if $detect->{pu};
plan tests => 2;

my $res = eval { $client->allo->recv };
diag $@ if $@;
isa_ok $res, 'AnyEvent::FTP::Response';
like eval { $res->code }, qr{^20[02]$}, 'code = ' . eval { $res->code };
diag $@ if $@;

$client->quit->recv;

