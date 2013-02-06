use strict;
use warnings;
use autodie;
use v5.10;
use File::Spec;
use File::HomeDir;
use FindBin ();
use YAML::XS qw( LoadFile );

my @services = do {
  open my $fh, '<', '/etc/services';
  map { [split /\t/]->[0] } grep /^(..)?ftp\s/, <$fh>;
};

chdir "$FindBin::Bin/..";

foreach my $service (@services)
{
  local $ENV{AEF_CONFIG} = File::Spec->catfile(File::HomeDir->my_home, '.ftptest', 'localhost.yml');
  local $ENV{AEF_PORT} = $service;
  say "[$service]";
  system 'prove', '-l', '-j', 3;
}

my @list = do {
  my $dir = File::Spec->catdir(File::HomeDir->my_home, '.ftptest');
  my $dh;
  opendir DIR, $dir;
  my @list = readdir DIR;
  closedir DIR;
  map { File::Spec->catfile(File::HomeDir->my_home, '.ftptest', $_) } grep !/^localhost\.yml$/, grep !/^\./, @list;
};

foreach my $config (@list)
{
  local $ENV{AEF_REMOTE} = LoadFile($config)->{remote};
  local $ENV{AEF_CONFIG} = $config;
  say "[$config]";
  system 'prove', '-l', '-j', 3;
}
