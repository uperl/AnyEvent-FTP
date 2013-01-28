use strict;
use warnings;
use v5.10;
use Test::More tests => 15;
use AnyEvent::FTP::Client;
use FindBin ();
require "$FindBin::Bin/lib.pl";

my $done = AnyEvent->condvar;

my $client = eval { AnyEvent::FTP::Client->new( on_close => sub { $done->send } ) };
diag $@ if $@;
isa_ok $client, 'AnyEvent::FTP::Client';

our $config;

prep_client( $client );

do {
  my $condvar = eval { $client->connect($config->{host}, $config->{port}) };
  diag $@ if $@;
  
  my $res = eval { $condvar->recv };
  diag $@ if $@;
  
  isa_ok $res, 'AnyEvent::FTP::Response';
  is $res->code, 220, 'code = 220';
};

is eval { $client->_send(USER => $config->{user})->recv->code }, 331, 'code = 331';
diag $@ if $@;
is eval { $client->_send(PASS => $config->{pass})->recv->code }, 230, 'code = 230';
diag $@ if $@;
is eval { $client->_send('QUIT')                 ->recv->code }, 221, 'code = 221';
diag $@ if $@;

$done->recv;
$done = AnyEvent->condvar;

is eval { $client->connect($config->{host}, $config->{port})->recv->code }, 220, 'code = 220';
diag $@ if $@;

my $cv = $client->_send('HELP');

is eval { $client->_send(USER => 'bogus')->recv->code }, 331, 'code = 331';
diag $@ if $@;
is eval { $client->_send(PASS => 'bogus')->recv->code }, 530, 'code = 530';
is eval { $client->_send('QUIT')                 ->recv->code }, 221, 'code = 221';
diag $@ if $@;

is $cv->recv->code, 214, 'code = 214';
$done->recv;
$done = AnyEvent->condvar;

my $cv1 = $client->_send(USER => $config->{user});
my $cv2 = $client->_send(PASS => $config->{pass});
my $cv3 = $client->_send('QUIT');

is eval { $client->connect($config->{host}, $config->{port})->recv->code }, 220, 'code = 220';
diag $@ if $@;

is $cv1->recv->code, 331, 'code = 331';
is $cv2->recv->code, 230, 'code = 230';
is $cv3->recv->code, 221, 'code = 221';

$done->recv;
