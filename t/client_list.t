use strict;
use warnings;
use v5.10;
use Test::More tests => 16;
use AnyEvent::FTP::Client;
use File::Temp qw( tempdir );
use File::Spec;
use FindBin ();
require "$FindBin::Bin/lib.pl";

our $config;
$config->{dir} = tempdir( CLEANUP => 1 );


foreach my $name (qw( foo bar baz ))
{
  my $fn = File::Spec->catfile($config->{dir}, "$name.txt");
  open my $fh, '>', $fn;
  close $fh;
}

my $dir2 = File::Spec->catdir($config->{dir}, "dir2");
mkdir $dir2;

foreach my $name (qw( dr.pepper coke pepsi ))
{
  my $fn = File::Spec->catfile($config->{dir}, 'dir2', "$name.txt");
  open my $fh, '>', $fn;
  close $fh;
}

foreach my $passive (0,1)
{

  my $client = AnyEvent::FTP::Client->new( passive => $passive );

  prep_client( $client );

  $client->connect($config->{host}, $config->{port})->recv;
  $client->login($config->{user}, $config->{pass})->recv;
  $client->type('I')->recv;
  $client->cwd($config->{dir})->recv;

  do {
    my $list = eval { $client->nlst->recv };
    diag $@ if $@;
    isa_ok $list, 'ARRAY';
    $list //= [];
    is_deeply [ sort @$list ], [ sort qw( foo.txt bar.txt baz.txt dir2 ) ], 'nlst 1';
    #note "list: $_" for @$list;
  };

  do {
    my $list = eval { $client->list->recv };
    diag $@ if $@;
    isa_ok $list, 'ARRAY';
    $list //= [];
    is scalar(@$list), 4, 'list length 4';
    #note "list: $_" for @$list;
  };

  do {
    my $list = eval { $client->nlst('dir2')->recv };
    diag $@ if $@;
    isa_ok $list, 'ARRAY';
    $list //= [];
    is_deeply [ sort @$list ], [ sort map { "dir2/$_.txt" } qw( dr.pepper coke pepsi ) ], 'nlst 1';
    #note "list: $_" for @$list;
  };

  do {
    my $list = eval { $client->list('dir2')->recv };
    diag $@ if $@;
    isa_ok $list, 'ARRAY';
    $list //= [];
    is scalar(@$list), 3, 'list length 3';
    #note "list: $_" for @$list;
  };

  $client->quit->recv;
}
