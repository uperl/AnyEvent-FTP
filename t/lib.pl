use strict;
use warnings;
use v5.10;
use YAML::XS qw( LoadFile );
use File::HomeDir;
use FindBin ();
use Path::Class ();

our $config;
our $detect;
$config = LoadFile($ENV{AEF_CONFIG} // (File::HomeDir->my_home . '/ftptest.yml'));
$config->{dir} //= "$FindBin::Bin/..";
$config->{dir} = Path::Class::Dir->new($config->{dir})->resolve;
$config->{port} //= $ENV{AEF_PORT} if defined $ENV{AEF_PORT};
$config->{host} //= $ENV{AEF_HOST} // 'localhost';
$config->{port} = getservbyname($config->{port}, "tcp")
  if defined $config->{port} && $config->{port} !~ /^\d+$/;

our $anyevent_test_timeout = AnyEvent->timer( after => 15, cb => sub { say STDERR "TIMEOUT"; exit } );

sub prep_client
{
  my($client) = @_;

  if($ENV{AEF_DEBUG})
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

  $client->on_greeting(sub {
    my $res = shift;
    $detect->{wu} = 1 if $res->message->[0] =~ /FTP server \(Version wu/;
    $detect->{pu} = 1 if $res->message->[0] =~ /Welcome to Pure-FTPd/;
    $detect->{vs} = 1 if $res->message->[0] =~ /\(vsFTPd /;
    $detect->{pl} = 1 if $res->message->[0] =~ /FTP server \(Net::FTPServer/;
    $detect->{pr} = 1 if $res->message->[0] =~ /ProFTPD/;
    $detect->{ms} = 1 if $res->message->[0] =~ /Microsoft FTP Service/;
  });


}

1;
