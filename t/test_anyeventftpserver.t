use strict;
use warnings;
use Test::More tests => 5;
use Test::AnyEventFTPServer;

my $server = create_ftpserver_ok;
isa_ok $server, 'AnyEvent::FTP::Server';
isa_ok $server->test_uri, 'URI';

my $client = $server->connect_ftpclient_ok;
isa_ok $client, 'AnyEvent::FTP::Client';
