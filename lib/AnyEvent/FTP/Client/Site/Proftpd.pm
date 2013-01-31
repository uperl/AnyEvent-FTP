package AnyEvent::FTP::Client::Site::Proftpd;

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

sub utime   { shift->{client}->push_command([SITE => "UTIME $_[0] $_[1]"]   ) }
sub mkdir   { shift->{client}->push_command([SITE => "MKDIR $_[0]"]         ) } 
sub rmdir   { shift->{client}->push_command([SITE => "RMDIR $_[0]"]         ) } 
sub symlink { shift->{client}->push_command([SITE => "SYMLINK $_[0] $_[1]"] ) }

sub ratio   { shift->{client}->push_command([SITE => "RATIO"]               ) }
sub quota   { shift->{client}->push_command([SITE => "QUOTA"]               ) }
sub help    { shift->{client}->push_command([SITE => "HELP $_[0]"]          ) }
sub chgrp   { shift->{client}->push_command([SITE => "CHGRP $_[0] $_[1]"]   ) }
sub chmod   { shift->{client}->push_command([SITE => "CHMOD $_[0] $_[1]"]   ) }

1;
