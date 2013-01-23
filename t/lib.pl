use strict;
use warnings;
use YAML::XS qw( LoadFile );
use File::HomeDir;

our $config = LoadFile(File::HomeDir->my_home . '/ftptest.yml');
