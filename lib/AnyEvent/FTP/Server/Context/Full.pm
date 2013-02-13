package AnyEvent::FTP::Server::Context::Full;

use strict;
use warnings;
use v5.10;
use base qw( AnyEvent::FTP::Server::Context );
use Role::Tiny::With;
use File::chdir;
use File::Spec;

# ABSTRACT: FTP Server client context class with full read/write access
# VERSION

with 'AnyEvent::FTP::Server::Role::Auth';
with 'AnyEvent::FTP::Server::Role::Help';
with 'AnyEvent::FTP::Server::Role::Old';
with 'AnyEvent::FTP::Server::Role::Type';

sub cwd
{
  my($self, $value) = @_;
  $self->{cwd} = $value if defined $value;
  $self->{cwd} //= '/';
}

sub rename_from
{
  my($self, $value) = @_;
  $self->{rename_from} = $value if defined $value;
  $self->{rename_from};
}

sub _not_logged_in
{
  my($self, $con) = @_;
  
  $con->send_response(530 => 'Please login with USER and PASS');
  $self->done;
  return;
}

sub cmd_cwd
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $dir = $req->args;

  eval {
    use autodie;
    local $CWD = $self->cwd;
    $CWD = $dir;
    $self->cwd($CWD);
    $con->send_response(250 => 'CWD command successful');
  };
  $con->send_response(550 => 'CWD error') if $@;
  
  $self->done;
}

sub cmd_cdup
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  eval {
    use autodie;
    local $CWD = $self->cwd;
    $CWD = File::Spec->updir;
    $self->cwd($CWD);
    $con->send_response(250 => 'CDUP command successful');
  };
  $con->send_response(550 => 'CDUP error') if $@;
  
  $self->done;
}

sub cmd_pwd
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $cwd = $self->cwd;
  $con->send_response(257 => "\"$cwd\" is the current directory");
  $self->done;
}

sub cmd_mkd
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $dir = $req->args;
  eval {
    use autodie;
    local $CWD = $self->cwd;
    mkdir $dir;
    $con->send_response(257 => "Directory created");
  };
  $con->send_response(550 => "MKD error") if $@;
  $self->done;
}

sub cmd_rmd
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $dir = $req->args;
  eval {
    use autodie;
    local $CWD = $self->cwd;
    rmdir $dir;
    $con->send_response(250 => "Directory removed");
  };
  $con->send_response(550 => "RMD error") if $@;
  $self->done;
}

sub cmd_dele
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $file = $req->args;
  eval {
    use autodie;
    local $CWD = $self->cwd;
    unlink $file;
    $con->send_response(250 => "File removed");
  };
  $con->send_response(550 => "DELE error") if $@;
  $self->done;
}

sub cmd_rnfr
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $path = $req->args;
  
  if($path)
  {
    eval {
      local $CWD = $self->cwd;
      if(!-e $path)
      {
        $con->send_response(550 => 'No such file or directory');
      }
      elsif(-w $path)
      {
        $self->rename_from($path);
        $con->send_response(350 => 'File or directory exists, ready for destination name');
      }
      else
      {
        $con->send_response(550 => 'Permission denied');
      }
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

sub cmd_rnto
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $path = $req->args;
  
  if(! defined $self->rename_from)
  {
    $con->send_response(503 => 'Bad sequence of commands');
  }
  elsif(!$path)
  {
    $con->send_response(501 => 'Invalid number of arguments');
  }
  else
  {
    eval {
      local $CWD = $self->cwd;
      if(! -e $path)
      {        
        rename $self->rename_from, $path;
        $con->send_response(250 => 'Rename successful');
      }
      else
      {
        $con->send_response(550 => 'File already exists');
      }
    };
    if(my $error = $@)
    {
      warn $error;
      $con->send_response(550 => 'Rename failed');
    }
  }
  $self->done;
}

sub cmd_stat
{
  my($self, $con, $req) = @_;
  
  my $path = $req->args;
  
  if($path)
  {
    if(-d $path)
    {
      $con->send_response(211 => "it's a directory");
    }
    elsif(-f $path)
    {
      $con->send_response(211 => "it's a file");
    }
    else
    {
      $con->send_response(450 => 'No such file or directory');
    }
  }
  else
  {
    $con->send_response(211 => "it's all good.");
  }
  $self->done;
}

1;
