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

sub help_cwd { 'CWD <sp> pathname' }

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

sub help_cdup { 'CDUP' }

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

sub help_pwd { 'PWD' }

sub cmd_pwd
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $cwd = $self->cwd;
  $con->send_response(257 => "\"$cwd\" is the current directory");
  $self->done;
}

sub help_mkd { 'MKD <sp> pathname' }

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

sub help_rmd { 'RMD <sp> pathname' }

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

sub help_dele { 'DELE <sp> pathname' }

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

sub help_rnfr { 'RNFR <sp> pathname' }

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

sub help_rnto { 'RNTO <sp> pathname' }

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

sub help_stat { 'STAT [<sp> pathname]' }

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

#################################################

use AnyEvent::Socket qw( tcp_server tcp_connect );
use AnyEvent::Handle;
use File::Spec;

sub data
{
  my($self, $value) = @_;
  $self->{data} = $value if defined $value;
  $self->{data};
}

sub restart_offset
{
  my($self, $value) = @_;
  $self->{restart_offset} = $value if defined $value;
  $self->{restart_offset};
}

sub clear_data
{
  my($self) = @_;
  delete $self->{data};
  delete $self->{restart_offset};
}

sub cmd_pasv
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;

  my $count = 0;

  tcp_server undef, undef, sub {
    my($fh, $host, $port) = @_;
    return close $fh if ++$count > 1;

    my $handle;
    $handle = AnyEvent::Handle->new(
      fh => $fh,
      on_error => sub {
        $_[0]->destroy;
        undef $handle;
      },
      on_eof => sub {
        $handle->destroy;
        undef $handle;
      },
      autocork => 1,
    );
    
    $self->data($handle);
    # FIXME this should be with the 227 message below.
    $self->done;
    
  }, sub {
    my($fh, $host, $port) = @_;
    my $ip_and_port = join(',', split(/\./, $con->ip), $port >> 8, $port & 0xff);

    my $w;
    $w = AnyEvent->timer(after => 0, cb => sub {
      $con->send_response(227 => "Entering Passive Mode ($ip_and_port)");
      undef $w;
    });
    
  };
  
  return;
}

sub cmd_port
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  if($req->args =~ /(\d+,\d+,\d+,\d+),(\d+),(\d+)/)
  {
    my $ip = join '.', split /,/, $1;
    my $port = $2*256 + $3;
    
    tcp_connect $ip, $port, sub {
      my($fh) = @_;
      unless($fh)
      {
        $con->send_response(500 => "Illegal PORT command");
        $self->done;
        return;
      }
      
      my $handle;
      $handle = AnyEvent::Handle->new(
        fh => $fh,
        on_error => sub {
          $_[0]->destroy;
          undef $handle;
        },
        on_eof => sub {
          $handle->destroy;
          undef $handle;
        },
      );
      
      $self->data($handle);
      $con->send_response(200 => "Port command successful");
      $self->done;
      
    };
    
  }
  else
  {
    $con->send_response(500 => "Illegal PORT command");
    $self->done;
    return;
  }
}

sub cmd_rest
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  if($req->args =~ /^\s*(\d+)\s*$/)
  {
    my $offset = $1;
    $con->send_response(350 => "Restarting at $offset.  Send STORE or RETRIEVE to initiate transfer");
    $self->restart_offset($offset);
  }
  else
  {
    $con->send_response(501 => "REST requires a value greater than or equal to 0");
  }
  $self->done;
}

sub cmd_retr
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $fn = $req->args;
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;
    
    if(-r $fn)
    {
      # FIXME: this blocks
      my $type = $self->type eq 'A' ? 'ASCII' : 'Binary';
      my $size = -s $fn;
      $con->send_response(150 => "Opening $type mode data connection for $fn ($size bytes)");
      open my $fh, '<', $fn;
      binmode $fh;
      seek $fh, $self->restart_offset, 0 if $self->restart_offset;
      $self->data->push_write(do { local $/; <$fh> });
      close $fh;
      $self->data->push_shutdown;
      $con->send_response(226 => 'Transfer complete');
    }
    elsif(-e $fn)
    {
      $con->send_response(550 => 'Permission denied');
    }
    else
    {
      $con->send_response(550 => 'No such file');
    }
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
  };
  $self->clear_data;
  $self->done;
}

sub cmd_nlst
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $dir = $req->args || '.';
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;
    
    $con->send_response(150 => "Opening ASCII mode data connection for file list");
    my $dh;
    opendir $dh, $dir;
    my @list = 
      map { $req->args ? File::Spec->catfile($dir, $_) : $_ } 
      sort 
      grep !/^\.\.?$/, 
      readdir $dh;
    closedir $dh;
    $self->data->push_write(join '', map { $_ . "\015\012" } @list);
    $self->data->push_shutdown;
    $con->send_response(226 => 'Transfer complete');
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
  };
  $self->clear_data;
  $self->done;
}

sub cmd_list
{
  my($self, $con, $req) = @_;
  
  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $dir = $req->args || '.';
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;
    
    $con->send_response(150 => "Opening ASCII mode data connection for file list");
    my $dh;
    opendir $dh, $dir;
    $self->data->push_write(join "\015\012", split /\n/, `ls -l $dir`);
    closedir $dh;
    $self->data->push_write("\015\012");
    $self->data->push_shutdown;
    $con->send_response(226 => 'Transfer complete');
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
  };
  $self->clear_data;
  $self->done;
}

sub cmd_stor
{
  my($self, $con, $req) = @_;

  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $fn = $req->args;
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;

    my $type = $self->type eq 'A' ? 'ASCII' : 'Binary';
    $con->send_response(150 => "Opening $type mode data connection for $fn");

    open my $fh, '>', $fn;
    binmode $fh;
    $self->data->on_read(sub {
      $self->data->push_read(sub {
        print $fh $_[0]{rbuf};
        $_[0]{rbuf} = '';
      });
    });
    $self->data->on_error(sub {
      close $fh;
      $self->data->push_shutdown;
      $con->send_response(226 => 'Transfer complete');
      $self->clear_data;
      $self->done;
    });
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
    $self->clear_data;
    $self->done;
  };
}

sub cmd_appe
{
  my($self, $con, $req) = @_;

  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $fn = $req->args;
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;

    my $type = $self->type eq 'A' ? 'ASCII' : 'Binary';
    $con->send_response(150 => "Opening $type mode data connection for $fn");

    open my $fh, '>>', $fn;
    binmode $fh;
    $self->data->on_read(sub {
      $self->data->push_read(sub {
        print $fh $_[0]{rbuf};
        $_[0]{rbuf} = '';
      });
    });
    $self->data->on_error(sub {
      close $fh;
      $self->data->push_shutdown;
      $con->send_response(226 => 'Transfer complete');
      $self->clear_data;
      $self->done;
    });
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
    $self->clear_data;
    $self->done;
  };
}

use File::Temp qw( tempfile );

sub cmd_stou
{
  my($self, $con, $req) = @_;

  return $self->_not_logged_in($con) unless $self->authenticated;
  
  my $fn = $req->args;
  
  unless(defined $self->data)
  {
    $con->send_response(425 => 'Unable to build data connection');
    return;
  }
  
  eval {
    use autodie;
    local $CWD = $self->cwd;

    my $fh;

    if($fn && ! -e $fn)
    {
      open $fh, '>', $fn;
    }
    else
    {
      ($fh,$fn) = tempfile( "aefXXXXXX", TMPDIR => 0 )
    }

    my $type = $self->type eq 'A' ? 'ASCII' : 'Binary';
    $con->send_response(150 => "FILE: $fn");

    binmode $fh;
    $self->data->on_read(sub {
      $self->data->push_read(sub {
        print $fh $_[0]{rbuf};
        $_[0]{rbuf} = '';
      });
    });
    $self->data->on_error(sub {
      close $fh;
      $self->data->push_shutdown;
      $con->send_response(226 => 'Transfer complete');
      $self->clear_data;
      $self->done;
    });
  };
  if(my $error = $@)
  {
    warn $error;
    $con->send_response(500 => 'FIXME');
    $self->clear_data;
    $self->done;
  };
}

1;
