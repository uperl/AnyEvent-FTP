package AnyEvent::FTP::UNIX;

use strict;
use warnings;
use v5.10;

# ABSTRACT: UNIX implementations for AnyEvent::FTP
# VERSION

=head1 SYNOPSIS

 use AnyEvent::FTP::UNIX;
 
 # interface using user fred
 my $unix = AnyEvent::FTP::UNIX->new('fred');
 $unix->jail;            # chroot
 $unix->drop_privileges; # transform into user fred

=head1 DESCRIPTION

This class provides some utility functionality for interacting with the
UNIX and UNIX like operating systems.

=cut

sub new
{
  my($class, $query) = @_;
  my($name, $pw, $uid, $gid, $quota, $comment, $gcos, $dir, $shell, $expire) = getpwnam $query;
  
  die "user not found" unless $name;
  
  my @groups;

  setgrent;
  
  my @grent;
  while(@grent = getgrent)
  {
    my($group,$pw,$gid,$members) = @grent;
    
    foreach my $member (split /\s+/, $members)
    {
      push @groups, $gid if $member eq $name;
    }
  }
  
  return bless {
    name   => $name,
    uid    => $uid,
    gid    => $gid,
    home   => $dir,
    shell  => $shell,
    groups => \@groups,
  }, $class;
}

=head1 METHODS

=head2 $unix-E<gt>jail

C<chroot> to the users' home directory.  Requires root and the chroot function.

=cut

sub jail
{
  my($self) = @_;
  chroot $self->{home};
  return $self;
}

=head2 $unix-E<gt>drop_privileges

Drop super user privileges

=cut

sub drop_privileges
{
  my($self) = @_;
  
  $) = join ' ', $self->{gid}, $self->{gid}, @{ $self->{groups} };
  $> = $self->{uid};
  
  $( = $self->{gid};
  $< = $self->{uid};

  return $self;
}

1;
