package AnyEvent::FTP::Request;

use strict;
use warnings;
use v5.10;
use overload '""' => sub { shift->as_string };

# ABSTRACT: Request class for asynchronous ftp server
# VERSION

sub new
{
  my($class, $cmd, $args, $raw) = @_;
  bless { command => $cmd, args => $args, raw => $raw }, $class;
}

sub command { shift->{command} }
sub args    { shift->{args}    }
sub raw     { shift->{raw}     }

1;
