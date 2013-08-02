package AnyEvent::FTP::Server::Context::Full;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use File::chdir;
use File::Spec;
use File::Temp qw( tempfile );

extends 'AnyEvent::FTP::Server::Context::FS';

# ABSTRACT: FTP Server client context class with full read/write access
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::Server;
 
 my $server = AnyEvent::FTP::Server->new(
   default_context => 'AnyEvent::FTP::Server::Context::Full',
 );

=head1 DESCRIPTION

This class provides a context for L<AnyEvent::FTP::Server> which uses the
actual filesystem to provide storage.

=head1 ROLES

This class consumes these roles:

=over 4

L<AnyEvent::FTP::Server::Role::TransferPrep>

=back

=cut

with 'AnyEvent::FTP::Server::Role::TransferPrep';

=head1 COMMANDS

In addition to the commands provided by the above roles,
this context provides these FTP commands:

=over 4

=item RETR

=cut

sub help_retr { 'RETR <sp> pathname' }

sub cmd_retr
{
  my($self, $con, $req) = @_;
  
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

=item NLST

=cut

sub help_nlst { 'NLST [<sp> (pathname)]' }

sub cmd_nlst
{
  my($self, $con, $req) = @_;
  
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

=item LIST

=cut

sub help_list { 'LIST [<sp> pathname]' }

sub cmd_list
{
  my($self, $con, $req) = @_;
  
  my $dir = $req->args || '.';
  $dir = '.' if $dir eq '-l';
  
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

=item STOR

=cut

sub help_stor { 'STOR <sp> pathname' }

sub cmd_stor
{
  my($self, $con, $req) = @_;

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

=item APPE

=cut

sub help_appe { 'APPE <sp> pathname' }

sub cmd_appe
{
  my($self, $con, $req) = @_;

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

=item STOU

=cut

sub help_stou { 'STOU (store unique filename)' }

sub cmd_stou
{
  my($self, $con, $req) = @_;

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

=back

=cut

