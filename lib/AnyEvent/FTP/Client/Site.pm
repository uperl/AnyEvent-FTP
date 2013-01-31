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

# TODO: use AUTOLOAD for this
sub proftpd
{
  require AnyEvent::FTP::Client::Site::Proftpd;
  AnyEvent::FTP::Client::Site::Proftpd->new(shift->{client});
}

1;
