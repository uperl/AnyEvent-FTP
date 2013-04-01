package AnyEvent::FTP::Server::Role::Auth;

use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Authentication role for FTP server
# VERSION

sub user
{
  my($self, $value) = @_;
  $self->{user} = $value if defined $value;
  $self->{user};
}

sub authenticated { shift->{authenticated} }

sub authenticator
{
  my($self, $value) = @_;
  $self->{authenticator} = $value if defined $value;
  $self->{authenticator} //= sub { 0 };
}

sub bad_authentication_delay
{
  my($self, $value) = @_;
  $self->{bad_authentication_delay} = $value if defined $value;
  $self->{bad_authentication_delay} //= 5;
}

sub help_user { 'USER <sp> username' }

sub cmd_user
{
  my($self, $con, $req) = @_;
  
  my $user = $req->args;
  $user =~ s/^\s+//;
  $user =~ s/\s+$//;
  
  if($user ne '')
  {
    $self->user($user);
    $con->send_response(331 => "Password required for $user");
  }
  else
  {
    $con->send_response(530 => "USER requires a parameter");
  }
  
  $self->done;
}

sub help_pass { 'PASS <sp> password' }

sub cmd_pass
{
  my($self, $con, $req) = @_;
  
  my $user = $self->user;
  my $pass = $req->args;
  
  unless(defined $user)
  {
    $con->send_response(503 => 'Login with USER first');
    $self->done;
    return;
  }
  
  if($self->authenticator->($user, $pass))
  {
    $con->send_response(230 => "User $user logged in");
    $self->{authenticated} = 1;
    $self->emit(auth => $user);
    $self->done;
  }
  else
  {
    my $delay = $self->bad_authentication_delay;
    if($delay > 0)
    {
      my $timer;
      $timer = AnyEvent->timer( after => 5, cb => sub {
        $con->send_response(530 => 'Login incorrect');
        $self->done;
        undef $timer;
      });
    }
    else
    {
      $con->send_response(530 => 'Login incorrect');
      $self->done;
    }
  }
}

1;
