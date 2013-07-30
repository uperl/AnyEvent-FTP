use strict;
use warnings;
use AnyEvent;
use AnyEvent::FTP::Client;

my $client = AnyEvent::FTP::Client->new( passive => 1);

my $done = AnyEvent->condvar;

$client->connect('ftp.cpan.org', 21)->recv;

# login using 'ftp' user and 'username@' as password
$client->login('ftp', $ENV{USER} . '@')->recv;
  
# use binary mode
$client->type('I')->recv;
      
# change into /pub/CPAN/src directory
$client->cwd('/pub/CPAN/src')->recv;
      
# download the file directly into a filehandle
open my $fh, '>', 'perl-5.16.3.tar.gz';
$client->retr('perl-5.16.3.tar.gz', $fh)->recv;
