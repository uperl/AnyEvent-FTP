use strict;
use warnings;
use v5.10;
use Test::More tests => 9;
use AnyEvent::FTP::Client;
use File::Temp qw( tempdir );
use File::Spec;
use FindBin ();
require "$FindBin::Bin/lib.pl";

our $config;
$config->{dir} = tempdir( CLEANUP => 1 );

my $client = AnyEvent::FTP::Client->new;

prep_client( $client );

$client->connect($config->{host}, $config->{port})->recv;
$client->login($config->{user}, $config->{pass})->recv;
$client->type('I')->recv;
$client->cwd($config->{dir})->recv;

my $fn = File::Spec->catfile($config->{dir}, 'foo.txt');
do {
  open my $fh, '>', $fn;
  say $fh "line 1";
  say $fh "line 2";
  close $fh;
};

do {
  my $data = '';
  my $ret = eval { $client->retr('foo.txt', sub { $data .= shift })->recv; };
  diag $@ if $@;
  isa_ok $ret, 'AnyEvent::FTP::Response';
  my @data = split /\015?\012/, $data;
  is $data[0], 'line 1';
  is $data[1], 'line 2';
};

do {
  my $data = '';
  my $ret = eval { $client->retr('foo.txt', \$data)->recv; };
  diag $@ if $@;
  isa_ok $ret, 'AnyEvent::FTP::Response';
  my @data = split /\015?\012/, $data;
  is $data[0], 'line 1';
  is $data[1], 'line 2';
};

do {
  my $data = '';
  open my $fh, '>', \$data;
  my $ret = eval { $client->retr('foo.txt', $fh)->recv; };
  diag $@ if $@;
  close $fh;
  isa_ok $ret, 'AnyEvent::FTP::Response';
  my @data = split /\015?\012/, $data;
  is $data[0], 'line 1';
  is $data[1], 'line 2';
};

$client->quit->recv;
