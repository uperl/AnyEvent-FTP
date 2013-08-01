use strict;
use warnings;
use Test::More tests => 8;
use Test::AnyEventFTPServer;

my $server = create_ftpserver_ok;
isa_ok $server, 'AnyEvent::FTP::Server';
isa_ok $server->test_uri, 'URI';

my $client = $server->connect_ftpclient_ok;
isa_ok $client, 'AnyEvent::FTP::Client';

my $response = $client->help->recv;
is $response->code, 214, "help response code = 214";

$response = $client->quit->recv;
is $response->code, 221, "quit response code = 221";

$server->help_coverage_ok;
