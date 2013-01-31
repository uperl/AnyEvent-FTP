package AnyEvent::FTP::Client::Site::NetFtpServer;

use strict;
use warnings;
use v5.10;

# ABSTRACT: Site specific commands for Net::FTPServer
# VERSION

sub new
{
  my($class, $client) = @_;
  bless { client => $client }, $class;
}

# TODO add a test for this
sub version { shift->{client}->push_command([SITE => 'VERSION'] ) }

# also ALIAS ARCHIVE CDPATH CHECKMETHOD CHECKSUM EXEC IDLE SYNC VERSION

1;
