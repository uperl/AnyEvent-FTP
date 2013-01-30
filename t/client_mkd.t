use strict;
use warnings;
use v5.10;
use Test::More tests => 6;
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

  do {
    my $ret = eval { $client->mkd('foo')->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    
    my $dir_name = File::Spec->catdir($config->{dir}, 'foo');
    ok -d $dir_name, "dir created: $dir_name";
    
    rmdir $dir_name;
    
    ok !-d $dir_name, "dir deleted";
  };
  
  $client->quit->recv;
}
