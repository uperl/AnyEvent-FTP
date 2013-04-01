package AnyEvent::FTP::Server::Role::Old;

use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Role for old archaic FTP server commands
# VERSION

sub help_allo { 'ALLO is not implemented (ignored)' }

sub cmd_allo
{
  my($self, $con, $req) = @_;
  $con->send_response(202 => 'No storage allocation necessary');
  $self->done;
}

sub help_noop { 'NOOP' }

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

sub help_syst { 'SYST' }

sub cmd_syst
{
  my($self, $con, $req) = @_;
  $con->send_response(215 => $self->syst);
  $self->done;
}

1;
