package AnyEvent::FTP::Client::Site::NetFtpServer;

use strict;
use warnings;
use 5.010;
use Moo;

extends 'AnyEvent::FTP::Client::Site::Base';

# ABSTRACT: Site specific commands for Net::FTPServer
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Client;
 my $client = AnyEvent::FTP::Client->new;
 $client->connect('ftp://netftpserver')->cb(sub {
   $client->site->net_ftp_server->version->cb(sub {
     my($res) = @_;
     # $res isa AnyEvent::FTP::Client::Response where
     # the message includes the server version
   });
 });


=head1 DESCRIPTION

This class provides the C<SITE> specific commands for L<Net::FTPServer>.

=head1 METHODS

=head2 $client-E<gt>site-E<gt>net_ftp_server-E<gt>version

Get the L<Net::FTPServer> version.

=cut

# TODO add a test for this
sub version { shift->client->push_command([SITE => 'VERSION'] ) }

=head1 CAVEATS

Other C<SITE> commands supported by L<Net::FTPServer>, but not implemented by
this class include:

=over 4

=item SITE ALIAS

=item SITE ARCHIVE

=item SITE CDPATH

=item SITE CHECKMETHOD

=item SITE CHECKSUM

=item SITE EXEC

=item SITE IDLE

=item SITE SYNC

=back

patches that include tests are welcome.

=cut

1;
