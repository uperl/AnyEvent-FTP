package AnyEvent::FTP::Server::Context::FullRW;

use strict;
use warnings;
use v5.10;
use base qw( AnyEvent::FTP::Server::Context );
use Role::Tiny::With;

with 'AnyEvent::FTP::Server::Role::Auth';
with 'AnyEvent::FTP::Server::Role::Help';
with 'AnyEvent::FTP::Server::Role::Old';
with 'AnyEvent::FTP::Server::Role::Type';

1;
