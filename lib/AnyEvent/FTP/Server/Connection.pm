package AnyEvent::FTP::Server::Connection;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use AnyEvent::FTP::Request;

# ABSTRACT: FTP Server connection class
# VERSION

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( request response close ));

has context => (
  is       => 'ro',
  required => 1,
);

has response_encoder => (
  is => 'ro',
  lazy => 1,
  default => sub {
    require AnyEvent::FTP::Server::UnambiguousResponseEncoder;
    AnyEvent::FTP::Server::UnambiguousResponseEncoder->new;
  },
);

has ip => (
  is       => 'ro',
  required => 1,
);

sub process_request
{
  my($self, $line) = @_;

  my $raw = $line;
  
  $self->emit(request => $raw);
  
  $line =~ s/\015?\012//g;

  if($line =~ s/^([A-Z]{1,4})\s?//i)
  {
    $self->context->push_request($self, AnyEvent::FTP::Request->new(uc $1, $line, $raw));
  }
  else
  {
    $self->context->invalid_syntax($self, $raw);
  }
  
  $self;
}

sub send_response
{
  my $self = shift;
  my $raw = $self->response_encoder->encode(@_);
  $self->emit(response => $raw);
  $self;
}

sub close
{
  my($self) = shift;
  $self->emit('close');
}

1;
