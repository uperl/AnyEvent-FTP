package AnyEvent::FTP::Server::Role::Help;

use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Help role for FTP server
# VERSION

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
      $con->send_response(214 => uc($topic) . " is a command");
    }
  }
  else
  {
    $con->send_response(502 => 'Unknown command');
  }
  
  $self->done;
}

1;
