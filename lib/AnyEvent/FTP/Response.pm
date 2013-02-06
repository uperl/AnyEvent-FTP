package AnyEvent::FTP::Response;

use strict;
use warnings;
use v5.10;
use overload '""' => sub { shift->as_string };

# ABSTRACT: Response class for asynchronous ftp client
# VERSION

sub new
{
  my($class, $code, $message) = @_;
  $message = [ $message ] unless ref($message) eq 'ARRAY';
  bless { code => $code, message => $message }, $class;
}

sub code           { shift->{code}            }
sub message        { shift->{message}         }
sub is_success     { shift->{code} !~ /^[45]/ }
sub is_preliminary { shift->{code} =~ /^1/    }

1;
