package AnyEvent::FTP::Server::Role::TransferFetch;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';

# ABSTRACT: Role that provides FTP commands RETR, NLST and LIST
# VERSION

=head1 SYNOPSIS

 package AnyEvent::FTP::Server::Context::MyContext;
 
 use Moo;
 extends 'AnyEvent::FTP::Server::Context';
 with 'AnyEvent::FTP::Server::Role::TransferFetch';

=head1 DESCRIPTION

This role provides the FTP commands C<RETR>, C<NLST> and C<LIST> for your
FTP server context.

=cut

requires 'transfer_open_read';
requires 'short_list';
requires 'long_list';

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
    
    my $error = $self->transfer_open_read($fn);
    if($error)
    { 
      $con->send_response(550 => $error);
    }
    else
    {
    }
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

1;

=back

=cut

