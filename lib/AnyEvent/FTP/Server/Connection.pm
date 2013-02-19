package AnyEvent::FTP::Server::Connection;

use strict;
use warnings;
use v5.10;
use Role::Tiny::With;
use Carp qw( croak );
use AnyEvent::FTP::Request;

# ABSTRACT: FTP Server connection class
# VERSION

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( request response close ));

sub new
{
  my $class = shift;
  my $args  = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});

  croak 'AnyEvent::FTP::Server::Connection requires a context'
    unless defined $args->{context};

  my $self = bless {
    context          => $args->{context},
    response_encoder => $args->{response_encoder} // do {
      require AnyEvent::FTP::Server::UnambiguousResponseEncoder;
      AnyEvent::FTP::Server::UnambiguousResponseEncoder->new;
    },
    ip               => $args->{ip},
  }, $class;
}

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

sub ip               { shift->{ip}               }
sub context          { shift->{context}          }
sub response_encoder { shift->{response_encoder} }

1;
