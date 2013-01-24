package AnyEvent::FTP::Response;

use strict;
use warnings;
use v5.10;
use overload '""' => sub { shift->as_string };

# ABSTRACT: Response class for asynchronous ftp client
# VERSION

sub code    { shift->{code}    }
sub message { shift->{message} }

sub get_address_and_port
{
  if(shift->{message}->[0] =~ /\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)/)
  {
    return ("$1.$2.$3.$4", $5*256+$6);
  }
  else
  {
    return;
  }
}

sub get_dir
{
  if(shift->{message}->[0] =~ /^"(.*)" is/)
  {
    my $dir = $1;
    $dir =~ s/""/"/;
    return $dir;
  }
  else
  {
    return;
  }
}

sub as_string
{
  my($self) = @_;
  
  sprintf "[%d] %s%s", $self->{code}, $self->{message}->[0], @{ $self->{message} } > 1 ? '...' : '';
}

sub is_success { shift->{code} !~ /^[45]/ }

1;
