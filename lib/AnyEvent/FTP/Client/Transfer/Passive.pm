package AnyEvent::FTP::Client::Transfer::Passive;

use strict;
use warnings;
use Moo;
use warnings NONFATAL => 'all';
use v5.10;
use AnyEvent::Socket qw( tcp_connect );

extends 'AnyEvent::FTP::Client::Transfer';

# ABSTRACT: Passive transfer class for asynchronous ftp client
# VERSION

sub BUILD
{
  my($self) = @_;
  
  my $local = $self->convert_local($self->local);
  
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
        
        $self->xfer($fh,$local);
      };
      return;
    }
    else
    {
      $res;
    }
  };

  $self->push_command(
    [ 'PASV', undef, $data_connection ],
    ($self->restart > 0 ? ([ REST => $self->restart ]) : ()),
    $self->command,
  );

  $self->cv->cb(sub {
    my $res = eval { shift->recv } // $@;
    $self->emit('close' => $res);
  });
}

package AnyEvent::FTP::Client::Transfer::Passive::Fetch;

use Moo;
extends 'AnyEvent::FTP::Client::Transfer::Passive';

with 'AnyEvent::FTP::Client::Role::FetchTransfer';

package AnyEvent::FTP::Client::Transfer::Passive::Store;

use Moo;
extends 'AnyEvent::FTP::Client::Transfer::Passive';

with 'AnyEvent::FTP::Client::Role::StoreTransfer';

package AnyEvent::FTP::Client::Transfer::Passive::List;

use Moo;
extends 'AnyEvent::FTP::Client::Transfer::Passive';

with 'AnyEvent::FTP::Client::Role::ListTransfer';

1;
