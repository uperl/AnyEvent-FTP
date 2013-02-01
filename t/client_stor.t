use strict;
use warnings;
use v5.10;
use Test::More tests => 28;
use AnyEvent::FTP::Client;
use File::Temp qw( tempdir );
use File::Spec;
use FindBin ();
require "$FindBin::Bin/lib.pl";

our $config;
$config->{dir} = tempdir( CLEANUP => 1 );

foreach my $passive (0,1)
{

  my $client = AnyEvent::FTP::Client->new( passive => $passive );

  prep_client( $client );

  $client->connect($config->{host}, $config->{port})->recv;
  $client->login($config->{user}, $config->{pass})->recv;
  $client->type('I')->recv;
  $client->cwd($config->{dir})->recv;

  my $fn = File::Spec->catfile($config->{dir}, 'foo.txt');

  do {
    my $data = 'some data';
    my $xfer = eval { $client->stor('foo.txt', \$data) };
    diag $@ if $@;
    isa_ok $xfer, 'AnyEvent::FTP::Transfer';
    my $ret = eval { $xfer->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    ok -e $fn, 'remote file created';
    my $remote = do {
      open my $fh, '<', $fn;
      local $/;
      <$fh>;
    };
    is $remote, $data, 'remote matches';
    is $xfer->remote_name, 'foo.txt', 'remote_name = foo.txt';
  };
  
  unlink $fn;
  ok !-e $fn, 'remote file deleted';
  
  do {
    my $data = 'some data';
    my $cb = do {
      my $buffer = $data;
      sub {
        my $tmp = $buffer;
        undef $buffer;
        $tmp;
      };
    };
    my $ret = eval { $client->stor('foo.txt', $cb)->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    ok -e $fn, 'remote file created';
    my $remote = do {
      open my $fh, '<', $fn;
      local $/;
      <$fh>;
    };
    is $remote, $data, 'remote matches';
  };
  
  unlink $fn;
  ok !-e $fn, 'remote file deleted';

  do {
    my $data = 'some data';
    my $glob = do {
      my $dir = tempdir( CLEANUP => 1);
      my $fn = File::Spec->catfile($dir, 'flub.txt');
      open my $out, '>', $fn;
      binmode $out;
      print $out $data;
      close $out;
      open my $in, '<', $fn;
      binmode $in;
      $in;
    };
    my $ret = eval { $client->stor('foo.txt', $glob)->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    ok -e $fn, 'remote file created';
    my $remote = do {
      open my $fh, '<', $fn;
      local $/;
      <$fh>;
    };
    is $remote, $data, 'remote matches';
  };
  
  unlink $fn;
  ok !-e $fn, 'remote file deleted';

  $client->quit->recv;
}

