package AnyEvent::FTP::Server::Role::Help;

use strict;
use warnings;
use 5.010;
use Moo::Role;

# ABSTRACT: Help role for FTP server
# VERSION

=head1 SYNOPSIS

Create a context:

# EXAMPLE: example/lib/AnyEvent/FTP/Server/Context/EchoContext.pm

Start a server with that context:

 % aeftpd --context EchoContext
 ftp://dfzcgohteq:igdcphxled@localhost:59402

Then connect to that server and test the C<HELP> command:

 % telnet localhost 59402
 Trying 127.0.0.1...
 Connected to localhost.
 Escape character is '^]'.
 220 aeftpd dev
 help
 214-The following commands are recognized:
 214-ECHO HELP
 214 Direct comments to devnull@bogus
 help help
 214 Syntax: HELP [<sp> command]
 help echo
 214 Syntax: ECHO <SP> text
 help bogus
 502 Unknown command
 quit
 221 Goodbye
 Connection closed by foreign host.

=head1 DESCRIPTION

This role provides a standard FTP C<HELP> command.  It finds any FTP commands (C<cmd_*>) you
have defined in your context class and the associated usage functions (C<help_*>) and implements
the C<HELP> command for you.

=cut

my %cmds;

sub help_help { 'HELP [<sp> command]' }

sub cmd_help
{
  my($self, $con, $req) = @_;
  
  my $topic = $req->args;
  $topic =~ s/^\s+//;
  $topic =~ s/\s+$//;
  $topic = lc $topic;

  if($topic eq '')
  {
    my $class = ref $self;
    unless(defined $cmds{$class})
    {
      no strict 'refs';
      $cmds{$class} = [ 
        sort map { s/^cmd_//; uc $_ } grep /^cmd_/, keys %{$class . '::'}
      ];
    }
  
    $con->send_response(214, [
      'The following commands are recognized:',
      join(' ', @{ $cmds{$class} }),
      'Direct comments to devnull@bogus',
    ]);
  }
  elsif($self->can("cmd_$topic"))
  {
    my $method = "help_$topic";
    if($self->can("help_$topic"))
    {
      $con->send_response(214 => 'Syntax: ' . $self->$method)
    }
    else
    {
      $con->send_response(502 => uc($topic) . " is a command without help");
    }
  }
  else
  {
    $con->send_response(502 => 'Unknown command');
  }
  
  $self->done;
}

1;
