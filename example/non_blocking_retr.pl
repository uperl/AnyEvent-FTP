use strict;
use warnings;
use AnyEvent;
use AnyEvent::FTP::Client;

my $client = AnyEvent::FTP::Client->new( passive => 1);

my $done = AnyEvent->condvar;

$client->connect('ftp.cpan.org', 21)->cb(sub {

  # login using 'ftp' user and 'username@' as password
  $client->login('ftp', $ENV{USER} . '@')->cb(sub {
  
    # use binary mode
    $client->type('I')->cb(sub {
      
      # change into /pub/CPAN/src directory
      $client->cwd('/pub/CPAN/src')->cb(sub {
      
        # download the file directly into a filehandle
        open my $fh, '>', 'perl-5.16.3.tar.gz';
        my $xfer = $client->retr('perl-5.16.3.tar.gz', $fh);
        print ref $xfer, "\n";
        $xfer->cb(sub {
          $done->send;
        });
      
      });
      
    });
  });
});

# receive the done message once the transfer is
# complete.  In real code you'd probably not
# want to do this because your event loop may
# not support blocking.
$done->recv;
