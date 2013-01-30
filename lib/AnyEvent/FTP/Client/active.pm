package AnyEvent::FTP::Client::active;

use strict;
use warnings;

# ABSTRACT: Active transfers for AnyEvent::FTP::Client
# VERSION

package AnyEvent::FTP::Client;

use AnyEvent::Socket qw( tcp_server );

sub _fetch_active
{
  my($self, $cmd_pair, $destination) = @_;
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

    $self->_send(PORT => $args)->cb(sub {
      my $res = shift->recv;
      if($res->is_success)
      {
        $self->_slurp_cmd($cmd_pair, $cv);
      }
      else
      { $cv->croak($res) }
    });
  };
  
  $cv;
}

sub _store_active
{
  my($self, $cmd_pair, $destination) = @_;
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

    $self->_send(PORT => $args)->cb(sub {
      my $res = shift->recv;
      if($res->is_success)
      {
        $self->_slurp_cmd($cmd_pair, $cv);
      }
      else
      { $cv->croak($res) }
    });
  };
  
  $cv;
}

1;
