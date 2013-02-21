package AnyEvent::FTP::UNIX;

use strict;
use warnings;

sub user_info
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
  
  return {
    name   => $name,
    uid    => $uid,
    gid    => $gid,
    home   => $dir,
    shell  => $shell,
    groups => \@groups,
  }
}

sub jail
{
  my($class, $info) = @_;
  chroot $info->{home};
  return;
}

sub drop_privileges
{
  my($class, $info) = @_;
  
  $) = join ' ', $info->{gid}, $info->{gid}, @{ $info->{groups} };
  $> = $info->{uid};
  
  $( = $info->{gid};
  $< = $info->{uid};

  return;
}

1;
