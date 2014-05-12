package AnyEvent::FTP::Client::Site::Base;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: base class for AnyEvent::FTP::Client::Site::* classes
# VERSION

sub BUILDARGS
{
  my($class, $client) = @_;
  return { client => $client };
}

has client => ( is => 'ro', required => 1 );

1;


