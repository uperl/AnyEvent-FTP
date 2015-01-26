package AnyEvent::FTP::Server::Role::ResponseEncoder;

use strict;
use warnings;
use 5.010;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Server response encoder role
# VERSION

requires 'encode';
requires 'new';

1;
