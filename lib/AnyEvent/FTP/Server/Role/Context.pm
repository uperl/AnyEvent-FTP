package AnyEvent::FTP::Server::Role::Context;

use strict;
use warnings;
use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Server connection context role
# VERSION

requires 'push_request';

1;
