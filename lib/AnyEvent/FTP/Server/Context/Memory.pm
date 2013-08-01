package AnyEvent::FTP::Server::Context::Memory;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

extends 'AnyEvent::FTP::Server::Context';

# ABSTRACT: FTP Server client context class with full read/write access
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Server;
 
 my $server = AnyEvent::FTP::Server->new(
   default_context => 'AnyEvent::FTP::Server::Context::Memory',
 );

=head1 DESCRIPTION

This class provides a context for L<AnyEvent::FTP::Server> which uses 
memory to provide storage.  Once the server process terminates, all
data stored is lost.

=head1 ROLES

This class consumes these roles:

=over 4

=item *

L<AnyEvent::FTP::Server::Role::Auth>

=item *

L<AnyEvent::FTP::Server::Role::Help>

=item *

L<AnyEvent::FTP::Server::Role::Old>

=item *

L<AnyEvent::FTP::Server::Role::Type>

=back

=cut

with 'AnyEvent::FTP::Server::Role::Auth';
with 'AnyEvent::FTP::Server::Role::Help';
with 'AnyEvent::FTP::Server::Role::Old';
with 'AnyEvent::FTP::Server::Role::Type';
with 'AnyEvent::FTP::Server::Role::TransferPrep';

=head1 COMMANDS

In addition to the commands provided by the above roles,
this context provides these FTP commands:

=over 4

=item CWD

=cut

sub help_cwd { 'CWD <sp> pathname' }

sub cmd_cwd
{
  my($self, $con, $req) = @_;
  
  my $dir = $req->args;

  eval {
    die 'FIXME';
    $con->send_response(250 => 'CWD command successful');
  };
  $con->send_response(550 => 'CWD error') if $@;
  
  $self->done;
}

=item CDUP

=cut

sub help_cdup { 'CDUP' }

sub cmd_cdup
{
  my($self, $con, $req) = @_;
  
  eval {
    die 'FIXME';
    $con->send_response(250 => 'CDUP command successful');
  };
  $con->send_response(550 => 'CDUP error') if $@;
  
  $self->done;
}

=item PWD

=cut

sub help_pwd { 'PWD' }

sub cmd_pwd
{
  my($self, $con, $req) = @_;
  
  $con->send_response(550 => 'CWD error');
  $self->done;
  # FIXME
  
  #my $cwd = $self->cwd;
  #$con->send_response(257 => "\"$cwd\" is the current directory");
  #$self->done;
}

=item SIZE

=cut

sub help_size { 'SIZE <sp> pathname' }

sub cmd_size
{
  my($self, $con, $req) = @_;
  
  eval {
    die 'FIXME';
    #if(-d $req->args)
    #{
    #  $con->send_response(550 => $req->args . ": not a regular file");
    #}
    #elsif(-e $req->args)
    #{
    #  my $size = -s $req->args;
    #  $con->send_response(213 => $size);
    #}
    #else
    #{
    #  die;
    #}
  };
  if($@)
  {
    $con->send_response(550 => $req->args . ": No such file or directory");
  }
  $self->done;
}

=item MKD

=cut

sub help_mkd { 'MKD <sp> pathname' }

sub cmd_mkd
{
  my($self, $con, $req) = @_;
  
  my $dir = $req->args;
  eval {
    die 'FIXME';
    $con->send_response(257 => "Directory created");
  };
  $con->send_response(550 => "MKD error") if $@;
  $self->done;
}

=item RMD

=cut

sub help_rmd { 'RMD <sp> pathname' }

sub cmd_rmd
{
  my($self, $con, $req) = @_;
  
  my $dir = $req->args;
  eval {
    die 'FIXME';
    $con->send_response(250 => "Directory removed");
  };
  $con->send_response(550 => "RMD error") if $@;
  $self->done;
}

=item DELE

=cut

sub help_dele { 'DELE <sp> pathname' }

sub cmd_dele
{
  my($self, $con, $req) = @_;
  
  my $file = $req->args;
  eval {
    die 'FIXME';
    $con->send_response(250 => "File removed");
  };
  $con->send_response(550 => "DELE error") if $@;
  $self->done;
}

=item RNFR

=cut

sub help_rnfr { 'RNFR <sp> pathname' }

sub cmd_rnfr
{
  my($self, $con, $req) = @_;
  
  my $path = $req->args;
  
  if($path)
  {
    eval {
      die 'FIXME';
      #local $CWD = $self->cwd;
      #if(!-e $path)
      #{
      #  $con->send_response(550 => 'No such file or directory');
      #}
      #elsif(-w $path)
      #{
      #  $self->rename_from($path);
      #  $con->send_response(350 => 'File or directory exists, ready for destination name');
      #}
      #else
      #{
      #  $con->send_response(550 => 'Permission denied');
      #}
    };
    if(my $error = $@)
    {
      warn $error;
      $con->send_response(550 => 'Rename failed');
    }
  }
  else
  {
    $con->send_response(501 => 'Invalid number of arguments');
  }
  $self->done;
}

=item RNTO

=cut

sub help_rnto { 'RNTO <sp> pathname' }

sub cmd_rnto
{
  my($self, $con, $req) = @_;
  
  my $path = $req->args;
  
  $con->send_response(550 => 'Rename failed');
  
  # FIXME
  #
  #if(! defined $self->rename_from)
  #{
  #  $con->send_response(503 => 'Bad sequence of commands');
  #}
  #elsif(!$path)
  #{
  #  $con->send_response(501 => 'Invalid number of arguments');
  #}
  #else
  #{
  #  eval {
  #    local $CWD = $self->cwd;
  #    if(! -e $path)
  #    {        
  #      rename $self->rename_from, $path;
  #      $con->send_response(250 => 'Rename successful');
  #    }
  #    else
  #    {
  #      $con->send_response(550 => 'File already exists');
  #    }
  #  };
  #  if(my $error = $@)
  #  {
  #    warn $error;
  #    $con->send_response(550 => 'Rename failed');
  #  }
  #}
  $self->done;
}

=item STAT

=cut

sub help_stat { 'STAT [<sp> pathname]' }

sub cmd_stat
{
  my($self, $con, $req) = @_;
  
  my $path = $req->args;
  
  $con->send_response(450 => 'No such file or directory');
  # FIXME

  #if($path)
  #{
  #  if(-d $path)
  #  {
  #    $con->send_response(211 => "it's a directory");
  #  }
  #  elsif(-f $path)
  #  {
  #    $con->send_response(211 => "it's a file");
  #  }
  #  else
  #  {
  #    $con->send_response(450 => 'No such file or directory');
  #  }
  #}
  #else
  #{
  #  $con->send_response(211 => "it's all good.");
  #}
  $self->done;
}

1;

=back

=cut

