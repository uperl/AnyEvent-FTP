use strict;
use warnings;
use v5.10;
use Test::More;
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

  $client->on_greeting(sub {
    state $first = 0;
    return unless ++$first == 1;
    my $res = shift;
    plan skip_all => 'wu-ftpd does not support STOU'
      if $res->message->[0] =~ /FTP server \(Version wu/;
    plan tests => 12;
  });

  prep_client( $client );

  $client->connect($config->{host}, $config->{port})->recv;
  $client->login($config->{user}, $config->{pass})->recv;
  $client->type('I')->recv;
  $client->cwd($config->{dir})->recv;

  do {
    my $data = 'some data';
    my $xfer = eval { $client->stou(undef, \$data) };
    diag $@ if $@;
    isa_ok $xfer, 'AnyEvent::FTP::Transfer';
    my $ret = eval { $xfer->recv; };
    diag $@ if $@;
    isa_ok $ret, 'AnyEvent::FTP::Response';
    
    my @list = do {
      opendir my $dh, $config->{dir};
      grep !/^\./, readdir $dh;
    };
    
    is scalar(@list), 1, 'exactly one file';
    my $fn = File::Spec->catfile($config->{dir}, $list[0]);
    is $xfer->remote_name, $list[0], "remote_name = $list[0]";

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
