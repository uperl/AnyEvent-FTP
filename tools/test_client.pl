use strict;
use warnings;
use autodie;
use v5.10;
use FindBin ();

my @services = do {
  open my $fh, '<', '/etc/services';
  map { [split /\t/]->[0] } grep /^(..)?ftp\s/, <$fh>;
};

chdir "$FindBin::Bin/..";

foreach my $service (@services)
{
  local $ENV{AEF_PORT} = $service;
  say "[$service]";
  system 'prove', '-l', '-j', 3;
}
