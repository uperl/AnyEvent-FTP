use strict;
use warnings;
use v5.10;
use Test::More;
use AnyEvent::FTP::Client;
use FindBin ();
require "$FindBin::Bin/lib.pl";

my $client = AnyEvent::FTP::Client->new;

$client->on_greeting(sub {
  my $res = shift;
  plan skip_all => 'wu-ftpd does not support ALLO'
    if $res->message->[0] =~ /FTP server \(Version wu/;
});

prep_client( $client );
our $config;

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;

plan tests => 2;

my $res = eval { $client->allo->recv };
diag $@ if $@;
isa_ok $res, 'AnyEvent::FTP::Response';
like eval { $res->code }, qr{^20[02]$}, 'code = ' . eval { $res->code };
diag $@ if $@;

$client->quit->recv;

