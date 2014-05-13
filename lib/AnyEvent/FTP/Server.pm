package AnyEvent::FTP::Server;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server );
use AnyEvent::FTP::Server::Connection;
use Socket qw( unpack_sockaddr_in inet_ntoa );

# ABSTRACT: Simple asynchronous ftp server
# VERSION

$AnyEvent::FTP::Server::VERSION //= 'dev';

with 'AnyEvent::FTP::Role::Event';

__PACKAGE__->define_events(qw( bind connect ));

has hostname => (
  is       => 'ro',
);

has port => (
  is      => 'ro',
  default => sub { 21 },
);

has default_context => (
  is      => 'ro',
  default => sub { 'AnyEvent::FTP::Server::Context::FSRW' },
);

has welcome => (
  is      => 'ro',
  default => sub { [ 220 => "aeftpd $AnyEvent::FTP::Server::VERSION" ] },
);

has bindport => (
  is => 'rw',
);

has inet => (
  is      => 'ro',
  default => sub { 0 },
);

sub BUILD
{
  eval 'use ' . shift->default_context;
  die $@ if $@;
}

sub start
{
  my($self) = @_;
  $self->inet ? $self->_start_inet : $self->_start_standalone;
}

sub _start_inet
{
  my($self) = @_;
  
  my $con = AnyEvent::FTP::Server::Connection->new(
    context => $self->{default_context}->new,
    ip      => do {
      my $sockname = getsockname STDIN;
      my ($sockport, $sockaddr) = unpack_sockaddr_in ($sockname);
      inet_ntoa ($sockaddr);
    },
  );

  my $handle;
  $handle = AnyEvent::Handle->new(
    fh => *STDIN,
      on_error => sub {
        my($hdl, $fatal, $msg) = @_;
        $con->close;
        $_[0]->destroy;
        undef $handle;
        undef $con;
      },
      on_eof   => sub {
        $con->close;
        $handle->destroy;
        undef $handle;
        undef $con;
      },
  );
  
  $self->emit(connect => $con);

  STDOUT->autoflush(1);
  STDIN->autoflush(1);

  $con->on_response(sub {
    my($raw) = @_;
    print STDOUT $raw;
  });
    
  $con->on_close(sub {
    close STDOUT;
    exit;
  });
    
  $con->send_response(@{ $self->welcome });
    
  $handle->on_read(sub {
    $handle->push_read( line => sub {
      my($handle, $line) = @_;
      $con->process_request($line);
    });
  });
  
  $self;
}

sub _start_standalone
{
  my($self) = @_;
  
  my $prepare = sub {
    my($fh, $host, $port) = @_;
    $self->bindport($port);
    $self->emit(bind => $port);
  };
  
  my $connect = sub {
    my($fh, $host, $port) = @_;
    
    my $con = AnyEvent::FTP::Server::Connection->new(
      context => $self->{default_context}->new,
      ip => do {
        my($port, $addr) = unpack_sockaddr_in getsockname $fh;
        inet_ntoa $addr;
      },
    );
    
    my $handle;
    $handle = AnyEvent::Handle->new(
      fh       => $fh,
      on_error => sub {
        my($hdl, $fatal, $msg) = @_;
        $con->close;
        $_[0]->destroy;
        undef $handle;
        undef $con;
      },
      on_eof   => sub {
        $con->close;
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
    
    $con->send_response(@{ $self->welcome });
    
    $handle->on_read(sub {
      $handle->push_read( line => sub {
        my($handle, $line) = @_;
        $con->process_request($line);
      });
    });
  
  };
  
  tcp_server $self->hostname, $self->port || undef, $connect, $prepare;
  
  $self;
}

=head1 METHODS

=head2 $server-E<gt>bindport([$port])

Retrieves or sets the TCP port to bind to.

=head2 my $context = $server-E<gt>default_context()

Readonly: the default context class (can be set as a parameter in the
constructor).

=head2 $server-E<gt>hostname()

Readonly, and should be assigned at the constructor. The hostname to listen
on.

=head2 my $bool = $server-E<gt>inet()

Readonly (assignable via the constructor). If true, then assume a TCP
connection has been established by inet. The default (false) is to start
a standalone server.

=head2 my $port = $server-E<gt>port()

The port to listen to. Default is 21 - a different port can be assigned
at the constructor.

=head2 $server-E<gt>start()

Call this method to start the service.

=head2 my $welcome_message_array_ref = $server-E<gt>welcome();

The welcome messages as key value pairs. Read only and can be overridden by
the constructor.

=cut

1;
