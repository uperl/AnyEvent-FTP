use strict;
use warnings;
use Test::More tests => 4;
use AnyEvent::FTP::Response;

my $message = bless { code => 227, message => [ 'Entering Passive Mode (192,168,42,23,156,29)' ] }, 'AnyEvent::FTP::Response';

is $message->code, 227, 'code = 227';
like $message->message->[0], qr/Entering Passive Mode/, 'entering passive mode message';

my($ip, $port) = eval { $message->get_address_and_port };
diag $@ if $@;

# p1*256+p2
is $ip,   '192.168.42.23', 'ip = 192.168.42.23';
is $port, 156*256+29,      'port = ' . (156*256+29);
