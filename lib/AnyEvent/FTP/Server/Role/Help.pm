package AnyEvent::FTP::Server::Role::Help;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Help role for FTP server
# VERSION

sub cmd_help
{
  my($self, $con, $req) = @_;
  
  my $topic = $req->args;
  $topic =~ s/^\s+//;
  $topic =~ s/\s+$//;

  if($topic eq '' || $self->can("cmd_$topic"))
  {
    $con->send_response(214, [
      'The following commands are recognized:',
      'USER PASS HELP QUIT',
      'Direct comments to devnull@bogus',
    ]);
  }
  else
  {
    $con->send_response(502 => 'Unknown command');
  }
  
  $self->done;
}

1;
