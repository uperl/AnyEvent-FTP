package AnyEvent::FTP::Server::Role::Type;

use strict;
use warnings;
use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Type role for FTP server
# VERSION

sub type
{
  my($self, $value) = @_;
  $self->{type} = $value if defined $value;
  $self->{type} // 'A';
}

sub help_type { 'TYPE <sp> type-code (A, I)' }

sub cmd_type
{
  my($self, $con, $req) = @_;

  my $type = uc $req->args;
  $type =~ s/^\s+//;
  $type =~ s/\s+$//;
  
  if($type eq 'A' || $type eq 'I')
  {
    $self->type($type);
    $con->send_response(200 => "Type set to $type");
  }
  else
  {
    $con->send_response(500 => "Type not understood");
  }
  
  $self->done;
}

# TODO: STRU MODE

1;
