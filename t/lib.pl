use strict;
use warnings;
use YAML::XS qw( LoadFile );
use File::HomeDir;

our $config;
do {
  my $save_dir = $config->{dir};
  $config = LoadFile(File::HomeDir->my_home . '/ftptest.yml');
  $config->{dir} = $save_dir if defined $save_dir;
};

# FIXME this stoped working for some reason ?
our $anyevent_test_timeout = AnyEvent->timer( after => 5, cb => sub { say STDERR "TIMEOUT"; exit } );

sub prep_client
{
  my($client) = @_;

  if($ENV{ANYEVENT_FTP_DEBUG})
  {
    $client->on_send(sub {
      my($cmd, $arguments) = @_;
      $arguments //= '';
      $arguments = 'XXXX' if $cmd eq 'PASS';
      note "CLIENT: $cmd $arguments";
    });

    $client->on_each_response(sub {
      my $res = shift;
      note sprintf "SERVER: [ %d ] %s\n", $res->code, $_ for @{ $res->message };
    });
  }
}

1;
