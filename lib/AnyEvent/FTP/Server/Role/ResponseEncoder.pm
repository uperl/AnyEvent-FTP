package AnyEvent::FTP::Server::Role::ResponseEncoder;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Server response encoder role
# VERSION

requires 'encode';
requires 'new';

1;
