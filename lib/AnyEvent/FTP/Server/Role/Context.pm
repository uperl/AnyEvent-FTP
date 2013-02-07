package AnyEvent::FTP::Server::Role::Context;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Server connection context role
# VERSION

requires 'push_request';

1;
