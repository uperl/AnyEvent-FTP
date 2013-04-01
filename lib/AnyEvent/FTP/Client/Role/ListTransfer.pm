package AnyEvent::FTP::Client::Role::ListTransfer;

use v5.10;
use Moo::Role;
use warnings NONFATAL => 'all';

# ABSTRACT: Fetch transfer interface for AnyEvent::FTP objects
# VERSION

sub xfer
{
  my($self, $fh, $local) = @_;
  
  my $handle = $self->handle($fh);

  $handle->on_read(sub {
    $handle->push_read(line => sub {
      my($handle, $line) = @_;
      $line =~ s/\015?\012//g;
      push @{ $local }, $line;
    });
  });
}

sub convert_local
{
  my($self, $local) = @_;
  return $local;
}

sub push_command
{
  my $self = shift;
  my $cv = $self->{client}->push_command(
    @_,
  );
  
  $cv->cb(sub {
    eval { $cv->recv };
    my $err = $@;
    $self->{cv}->croak($err) if $err;
  });
  
  $self->on_eof(sub {
    $cv->cb(sub {
      my $res = eval { $cv->recv };
      $self->{cv}->send($res) unless $@;
    });
  });
}

1;
