package AnyEvent::FTP::Client::Site::Microsoft;

use strict;
use warnings;
use v5.10;

# ABSTRACT: Site specific commands for Microsoft FTP Service
# VERSION

sub new
{
  my($class, $client) = @_;
  bless { client => $client }, $class;
}

# TODO add a test for this
sub dirstyle { shift->{client}->push_command(['DIRSTYLE'] ) }

1;
