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
  plan skip_all => 'Net::FTPServer returns wrong code for ALLO'
    if $res->message->[0] =~ /FTP server \(Net::FTPServer/;
});

prep_client( $client );
our $config;

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;

plan tests => 2;

my $res = eval { $client->allo->recv };
diag $@ if $@;
isa_ok $res, 'AnyEvent::FTP::Response';
is eval { $res->code }, 202, 'code = 202';
diag $@ if $@;

$client->quit->recv;

