package AnyEvent::FTP::Client::passive;

use strict;
use warnings;

# ABSTRACT: Passive transfers for AnyEvent::FTP::Client
# VERSION

package AnyEvent::FTP::Client;

sub _fetch_passive
{
  my($self, $cmd_pair, $destination) = @_;
  
  my $cv = AnyEvent->condvar;
  
  $self->_send('PASV')->cb(sub {
    my $res = shift->recv;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          $cv->croak("unable to connect to data port: $!");
          return
        }
        
        $DB::single = 1;
        
        $self->_slurp_data($fh,$destination);
        $self->_slurp_cmd($cmd_pair, $cv);
      };
    }
    else
    { $cv->croak($res) }
  });
  
  return $cv;
}

sub _store_passive
{
  my($self, $cmd_pair, $destination) = @_;
  
  my $cv = AnyEvent->condvar;
  
  $self->_send('PASV')->cb(sub {
    my $res = shift->recv;
    my($ip, $port) = $res->get_address_and_port;
    if(defined $ip && defined $port)
    {
      tcp_connect $ip, $port, sub {
        my($fh) = @_;
        unless($fh)
        {
          $cv->croak("unable to connect to data port: $!");
          return
        }
        
        $DB::single = 1;
        
        $self->_spew_data($fh,$destination);
        $self->_slurp_cmd($cmd_pair, $cv);
      };
    }
    else
    { $cv->croak($res) }
  });
  
  return $cv;
}

1;
