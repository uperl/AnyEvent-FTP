package inc::ServerTests;

use Moose;
use namespace::autoclean;
use v5.10;
use Path::Class qw( file dir );
use YAML qw( LoadFile DumpFile );
use File::HomeDir;

with 'Dist::Zilla::Role::TestRunner';

sub test
{
  my($self, $target) = @_;

  my $test_root = dir('.')->absolute;
  
  my @services = do {
    open my $fh, '<', '/etc/services';
    map { [split /\s+/]->[0] } grep /^(..)?ftp\s/, <$fh>;
  };
  
  foreach my $service (@services)
  {
    my $dir = $test_root->subdir('t', 'server', $service);
    $dir->mkpath(0,0700);
    my $old = $test_root->file('t', 'lib.pl');
    my $new = $dir->file('lib.pl');
    symlink $old, $new;
    
    $old = file( File::HomeDir->my_home, 'etc', 'localhost.yml');
    $new = $dir->file('config.yml');
    
    my $config = LoadFile($old);
    $config->{port} = $service;
    DumpFile($new, $config);
  }
  
  foreach my $test_file (grep { $_->basename =~ /^client_/ } sort { $a->basename cmp $b->basename } $test_root->subdir('t')->children)
  {
    $self->zilla->log("test = $test_file");
    foreach my $service (@services)
    {
      my $link = $test_root->file('t', 'server', $service, $test_file->basename);
      symlink $test_file, $link;
    }
  }

  local $ENV{AEF_PORT} = 'from_config';
  system 'prove', '-br', 't/server';  
  $self->log_fatal('server test failure') unless $? == 0;
}

1;
