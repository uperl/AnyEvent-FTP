package AnyEvent::FTP::Response;

use strict;
use warnings;
use v5.10;

# ABSTRACT: Response class for asynchronous ftp client
# VERSION

sub code    { shift->{code}    }
sub message { shift->{message} }

1;
