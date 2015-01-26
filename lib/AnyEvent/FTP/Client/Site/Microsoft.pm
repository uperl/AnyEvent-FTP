package AnyEvent::FTP::Client::Site::Microsoft;

use strict;
use warnings;
use 5.010;
use Moo;
use warnings NONFATAL => 'all';

extends 'AnyEvent::FTP::Client::Site::Base';

# ABSTRACT: Site specific commands for Microsoft FTP Service
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Client;
 my $client = AnyEvent::FTP::Client->new;
 $client->connect('ftp://iisserver')->cb(sub {
   # toggle dir style
   $client->site->microsoft->dirstyle->cb(sub {
   
     $client->list->cb(sub {
       my $list = shift
       # $list is in first style.
       
       $client->site->microsoft->dirstyle->cb(sub {
       
         $client->list->cb(sub {
           my $list = shift;
           # list is in second style.
         });
       
       });
     });
   
   });
 });

=head1 DESCRIPTION

This class provides Microsoft's IIS SITE commands.

=head1 METHODS

=head2 $client-E<gt>site-E<gt>microsoft-E<gt>dirstyle

Toggle between directory listing output styles.

=cut

# TODO add a test for this
sub dirstyle { shift->client->push_command([SITE => 'DIRSTYLE'] ) }

1;
