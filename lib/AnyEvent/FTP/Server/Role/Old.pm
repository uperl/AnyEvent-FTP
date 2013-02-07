package AnyEvent::FTP::Server::Role::Old;

use strict;
use warnings;
use v5.10;
use Role::Tiny;

# ABSTRACT: Role for old archaic FTP server commands
# VERSION

sub cmd_allo
{
  my($self, $con, $req) = @_;
  $con->send_response(202 => 'No storage allocation necessary');
  $self->done;
}

sub cmd_noop
{
  my($self, $con, $req) = @_;
  $con->send_response(200 => 'NOOP command successful');
  $self->done;
}

sub syst
{
  my($self, $value) = @_;
  $self->{syst} = $value if defined $value;
  $self->{syst} //= 'UNIX Type: L8';
}

sub cmd_syst
{
  my($self, $con, $req) = @_;
  $con->send_response(215 => $self->syst);
  $self->done;
}

1;
