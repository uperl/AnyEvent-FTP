use strict;
use warnings;
use Test::More tests => 10;
use Test::AnyEventFTPServer;

foreach my $type (qw( Full Memory ))
{
  my $server = create_ftpserver_ok($type);
  my $client = $server->connect_ftpclient_ok;
  
  is $client->allo->recv->code, 202, "ALLO";
  is $client->noop->recv->code, 200, "NOOP";
  is $client->syst->recv->code, 215, "SYST";
}
