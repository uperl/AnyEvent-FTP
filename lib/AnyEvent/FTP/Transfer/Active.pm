package AnyEvent::FTP::Transfer::Active;

use strict;
use warnings;
use v5.10;
use base qw( AnyEvent::FTP::Transfer );
use AnyEvent::Socket qw( tcp_server );

# ABSTRACT: Active transfer class for asynchronous ftp client
# VERSION

# my($self, $cmd_pair, $destination, @prefix) = @_;

# args:
#  - command
#  - destination
#  - prefix
sub new
{
  my($class) = shift;
  my $args   = ref $_[0] eq 'HASH' ? (\%{$_[0]}) : ({@_});
  my $self = $class->SUPER::new($args);
  
  my $destination = $self->convert_destination($args->{destination});
  
  my $count = 0;
  my $guard;
  $guard = tcp_server $self->{client}->{my_ip}, undef, sub {
    my($fh, $host, $port) = @_;
    # TODO double check the host/port combo here.
    
    return close $fh if ++$count > 1;
    
    undef $guard; # close to additional connections.

    $self->xfer($fh,$destination);
  }, sub {
  
    my($fh, $host, $port) = @_;
    my $ip_and_port = join(',', split(/\./, $self->{client}->{my_ip}), $port >> 8, $port & 0xff);

    $self->{client}->push_command(
      @{ $args->{prefix} },
      [ PORT => $ip_and_port ],
      $args->{command},
      $self->{cv},
    );
  };
  
  $self;
}

package AnyEvent::FTP::Transfer::Active::Fetch;

use base qw( AnyEvent::FTP::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::FetchTransfer';

package AnyEvent::FTP::Transfer::Active::Store;

use base qw( AnyEvent::FTP::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::StoreTransfer';

package AnyEvent::FTP::Transfer::Active::List;

use base qw( AnyEvent::FTP::Transfer::Active );
use Role::Tiny::With;

with 'AnyEvent::FTP::Role::ListTransfer';

1;
