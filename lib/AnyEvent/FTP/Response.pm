package AnyEvent::FTP::Response;

use strict;
use warnings;
use v5.10;

# ABSTRACT: Response class for asynchronous ftp client
# VERSION

sub code    { shift->{code}    }
sub message { shift->{message} }

sub get_address_and_port
{
  if(shift->{message}->[0] =~ /\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/)
  {
    return ("$1.$2.$3.$4", $5*256+$6);
  }
  else
  {
    return;
  }
}

1;
