package AnyEvent::FTP::Role::Event;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Event interface for AnyEvent::FTP objects
# VERSION

sub define_events
{
  my $class = shift;
  
  foreach my $name (@_)
  {
    my $method_name = join '::', $class, "on_$name";
    my $method = sub { 
      my($self, $cb) = @_;
      push @{ $self->{event}->{$name} }, $cb;
      $self;
    };
    no strict 'refs';
    *$method_name = $method;
  }
}

sub emit
{
  my($self, $name, @args) = @_;
  $_->(@args) for @{ $self->{event}->{$name} };
}

1;
