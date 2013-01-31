package AnyEvent::FTP::Client::active;

use strict;
use warnings;

# ABSTRACT: Active transfers for AnyEvent::FTP::Client
# VERSION

package AnyEvent::FTP::Client;

use AnyEvent::Socket qw( tcp_server );

sub _fetch_active
{
  my($self, $cmd_pair, $destination, @prefix) = @_;
  my $cv = AnyEvent->condvar;
  
  my $count = 0;
  my $guard;
  $guard = tcp_server $self->{my_ip}, undef, sub {
    my($fh, $host, $port) = @_;
    # TODO double check the host/port combo here.
    
    return close $fh if ++$count > 1;
    
    undef $guard; # close to additional connections.

    $self->_slurp_data($fh,$destination);
  }, sub {
  
    my($fh, $host, $port) = @_;
    my $args = join(',', split(/\./, $self->{my_ip}), $port >> 8, $port & 0xff);

    $self->push_command(
      @prefix,
      [ PORT => $args ],
      $cmd_pair,
      $cv,
    );
  };
  
  $cv;
}

sub _store_active
{
  my($self, $cmd_pair, $destination, @prefix) = @_;
  my $cv = AnyEvent->condvar;
  
  my $count = 0;
  my $guard;
  $guard = tcp_server $self->{my_ip}, undef, sub {
    my($fh, $host, $port) = @_;
    # TODO double check the host/port combo here.
    
    return close $fh if ++$count > 1;
    
    undef $guard; # close to additional connections.

    $self->_spew_data($fh,$destination);
  }, sub {
  
    my($fh, $host, $port) = @_;
    my $args = join(',', split(/\./, $self->{my_ip}), $port >> 8, $port & 0xff);

    $self->push_command(
      @prefix,
      [ PORT => $args ],
      $cmd_pair,
      $cv,
    );
  };
  
  $cv;
}

1;
