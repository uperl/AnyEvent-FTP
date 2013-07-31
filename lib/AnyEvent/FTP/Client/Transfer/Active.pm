package AnyEvent::FTP::Client::Transfer::Active;

use strict;
use warnings;
use v5.10;
use base qw( AnyEvent::FTP::Client::Transfer );
use AnyEvent;
use AnyEvent::Socket qw( tcp_server );

# ABSTRACT: Active transfer class for asynchronous ftp client
# VERSION

# args:
#  - command
#  - local
#  - restart
sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  $args->{restart} //= 0;
  my $self = $class->SUPER::new($args);
  
  my $local = $self->convert_local($args->{local});
  
  my $count = 0;
  my $guard;
  $guard = tcp_server $self->{client}->{my_ip}, undef, sub {
    my($fh, $host, $port) = @_;
    # TODO double check the host/port combo here.
    
    return close $fh if ++$count > 1;
    
    undef $guard; # close to additional connections.

    $self->xfer($fh,$local);
  }, sub {
  
    my($fh, $host, $port) = @_;
    my $ip_and_port = join(',', split(/\./, $self->{client}->{my_ip}), $port >> 8, $port & 0xff);

    my $w;
    $w = AnyEvent->timer(after => 0, cb => sub {
      $self->push_command(
        [ PORT => $ip_and_port ],
        ($args->{restart} > 0 ? ([ REST => $args->{restart} ]) : ()),
        $args->{command},
      );
      undef $w;
    });
  };
  
  $self->{cv}->cb(sub {
    my $res = eval { shift->recv } // $@;
    $self->emit('close' => $res);
  });
  
  $self;
}

package AnyEvent::FTP::Client::Transfer::Active::Fetch;

use base qw( AnyEvent::FTP::Client::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Client::Role::FetchTransfer';

package AnyEvent::FTP::Client::Transfer::Active::Store;

use base qw( AnyEvent::FTP::Client::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Client::Role::StoreTransfer';

package AnyEvent::FTP::Client::Transfer::Active::List;

use base qw( AnyEvent::FTP::Client::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Client::Role::ListTransfer';

1;
