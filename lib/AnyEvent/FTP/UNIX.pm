package AnyEvent::FTP::UNIX;

use strict;
use warnings;
use v5.10;

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

sub jail
{
  my($self) = @_;
  chroot $self->{home};
  return $self;
}

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
