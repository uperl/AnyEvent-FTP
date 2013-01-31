package AnyEvent::FTP::Client::passive;

use strict;
use warnings;

# ABSTRACT: Passive transfers for AnyEvent::FTP::Client
# VERSION

package AnyEvent::FTP::Client;

sub _fetch_passive
{
  my($self, $cmd_pair, $destination, @prefix) = @_;

  my $data_connection = sub {
    my $res = shift;
    return if $res->is_preliminary;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          return "unable to connect to data port: $!";
        }
        
        $self->_slurp_data($fh,$destination);
      };
      return;
    }
    else
    {
      $res;
    }
  };
  
  $self->push_command(
    @prefix,
    [ 'PASV', undef, $data_connection ],
    $cmd_pair,
  );
}

sub _store_passive
{
  my($self, $cmd_pair, $destination, @prefix) = @_;

  my $data_connection = sub {
    my $res = shift;
    return if $res->is_preliminary;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          return "unable to connect to data port: $!";
        }
        
        $self->_spew_data($fh,$destination);
      };
      return;
    }
    else
    {
      $res;
    }
  };
  
  $self->push_command(
    @prefix,
    [ 'PASV', undef, $data_connection ],
    $cmd_pair,
  );
}

1;
