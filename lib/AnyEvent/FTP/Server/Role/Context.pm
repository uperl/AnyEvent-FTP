package AnyEvent::FTP::Server::Role::Context;

use strict;
use warnings;
use 5.010;
use Moo::Role;

# ABSTRACT: Server connection context role
# VERSION

requires 'push_request';

1;
