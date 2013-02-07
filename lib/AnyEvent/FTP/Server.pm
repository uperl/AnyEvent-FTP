package AnyEvent::FTP::Server;

use strict;
use warnings;
use v5.10;
use Role::Tiny::With;
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server );
use AnyEvent::FTP::Server::Connection;

# ABSTRACT: Simple asynchronous ftp server
# VERSION

$AnyEvent::FTP::Server::VERSION //= 'dev';

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( bind connect ));

sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = bless {
    hostname        => $args->{hostname},
    port            => $args->{port} // 21,
    default_context => $args->{default_context} // 'AnyEvent::FTP::Server::Context::FullRW',
    welcome         => $args->{welcome} // [ 220 => "aeftpd $AnyEvent::FTP::Server::VERSION" ],
  }, $class;
  
  eval 'use ' . $self->{default_context};
  die $@ if $@;
  
  $self;
}

sub start
{
  my($self) = @_;
  
  my $prepare = sub {
    my($fh, $host, $port) = @_;
    $self->{bindport} = $port;
    $self->emit(bind => $port);
  };
  
  my $connect = sub {
    my($fh, $host, $port) = @_;
    
    my $con = AnyEvent::FTP::Server::Connection->new(
      context => $self->{default_context}->new,
    );
    
    my $handle;
    $handle = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        my($hdl, $fatal, $msg) = @_;
        $_[0]->destroy;
        undef $handle;
        undef $con;
      },
      on_eof   => sub {
        $handle->destroy;
        undef $handle;
        undef $con;
      },
    );
    
    $self->emit(connect => $con);
    
    $con->on_response(sub {
      my($raw) = @_;
      $handle->push_write($raw);
    });
    
    $con->on_close(sub {
      $handle->push_shutdown;
    });
    
    $con->send_response(@{ $self->{welcome} });
    
    $handle->on_read(sub {
      $handle->push_read( line => sub {
        my($handle, $line) = @_;
        $con->process_request($line);
      });
    });
  
  };
  
  delete $self->{port} if $self->{port} == 0;
  
  tcp_server $self->{hostname}, $self->{port}, $connect, $prepare;
  
  $self;
}

sub bindport { shift->{bindport} }

1;
