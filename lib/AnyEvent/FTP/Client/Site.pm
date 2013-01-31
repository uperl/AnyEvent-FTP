package AnyEvent::FTP::Client::Site;

use strict;
use warnings;
use v5.10;

# ABSTRACT: Dispatcher for site specific ftp commands
# VERSION

sub new
{
  my($class, $client) = @_;
  bless { client => $client }, $class;
}

sub AUTOLOAD
{
  our $AUTOLOAD;
  my $self = shift;
  my $name = $AUTOLOAD;
  $name =~ s/^.*://;
  my $class = join('::', qw( AnyEvent FTP Client Site ), ucfirst($name) );
  eval qq{ use $class () };
  die $@ if $@;
  $class->new($self->{client});
}

# don't autoload DESTROY
sub DESTROY { }

1;
