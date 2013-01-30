use strict;
use warnings;
use v5.10;
use Test::More tests => 8;
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
    my $data = 'some data';
    my $ret = eval { $client->stou(undef, \$data)->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    
    my @list = do {
      opendir my $dh, $config->{dir};
      grep !/^\./, readdir $dh;
    };
    
    is scalar(@list), 1, 'exactly one file';
    my $fn = File::Spec->catfile($config->{dir}, $list[0]);

    my $remote = do {
      open my $fh, '<', $fn;
      local $/;
      <$fh>;
    };
    
    is $remote, $data, 'local/remote match';
    
    unlink $fn;
    
    ok !-e $fn, 'remote deleted';
  };
  
  $client->quit->recv;
}
