package AnyEvent::FTP::Server::Role::TransferPrep;

use strict;
use warnings;
use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';
use AnyEvent;
use AnyEvent::Socket qw( tcp_server tcp_connect );
use AnyEvent::Handle;

# ABSTRACT: Interface for PASV, PORT and REST commands
# VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=cut

sub data
{
  my($self, $value) = @_;
  $self->{data} = $value if defined $value;
  $self->{data};
}

sub restart_offset
{
  my($self, $value) = @_;
  $self->{restart_offset} = $value if defined $value;
  $self->{restart_offset};
}

sub clear_data
{
  my($self) = @_;
  delete $self->{data};
  delete $self->{restart_offset};
}

=head1 COMMANDS

=over 4

=item PASV

=cut

sub help_pasv { 'PASV (returns address/port)' }

sub cmd_pasv
{
  my($self, $con, $req) = @_;
  
  my $count = 0;

  tcp_server undef, undef, sub {
    my($fh, $host, $port) = @_;
    return close $fh if ++$count > 1;

    my $handle;
    $handle = AnyEvent::Handle->new(
      fh => $fh,
      on_error => sub {
        $_[0]->destroy;
        undef $handle;
      },
      on_eof => sub {
        $handle->destroy;
        undef $handle;
      },
      autocork => 1,
    );
    
    $self->data($handle);
    # FIXME this should be with the 227 message below.
    $self->done;
    
  }, sub {
    my($fh, $host, $port) = @_;
    my $ip_and_port = join(',', split(/\./, $con->ip), $port >> 8, $port & 0xff);

    my $w;
    $w = AnyEvent->timer(after => 0, cb => sub {
      $con->send_response(227 => "Entering Passive Mode ($ip_and_port)");
      undef $w;
    });
    
  };
  
  return;
}

=item PORT

=cut

sub help_port { 'PORT <sp> h1,h2,h3,h4,p1,p2' }

sub cmd_port
{
  my($self, $con, $req) = @_;
  
  if($req->args =~ /(\d+,\d+,\d+,\d+),(\d+),(\d+)/)
  {
    my $ip = join '.', split /,/, $1;
    my $port = $2*256 + $3;
    
    tcp_connect $ip, $port, sub {
      my($fh) = @_;
      unless($fh)
      {
        $con->send_response(500 => "Illegal PORT command");
        $self->done;
        return;
      }
      
      my $handle;
      $handle = AnyEvent::Handle->new(
        fh => $fh,
        on_error => sub {
          $_[0]->destroy;
          undef $handle;
        },
        on_eof => sub {
          $handle->destroy;
          undef $handle;
        },
      );
      
      $self->data($handle);
      $con->send_response(200 => "Port command successful");
      $self->done;
      
    };
    
  }
  else
  {
    $con->send_response(500 => "Illegal PORT command");
    $self->done;
    return;
  }
}

=item REST

=cut

sub help_rest { 'REST <sp> byte-count' }

sub cmd_rest
{
  my($self, $con, $req) = @_;
  
  if($req->args =~ /^\s*(\d+)\s*$/)
  {
    my $offset = $1;
    $con->send_response(350 => "Restarting at $offset.  Send STORE or RETRIEVE to initiate transfer");
    $self->restart_offset($offset);
  }
  else
  {
    $con->send_response(501 => "REST requires a value greater than or equal to 0");
  }
  $self->done;
}

1;

=back

=cut

