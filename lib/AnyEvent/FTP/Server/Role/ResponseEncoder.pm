package AnyEvent::FTP::Server::Role::ResponseEncoder;

use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Server response encoder role
# VERSION

requires 'encode';
requires 'new';

1;
