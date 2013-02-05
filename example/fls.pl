use strict;
use warnings;
use v5.10;
use URI;
use AnyEvent::FTP::Client;
use Term::Prompt qw( prompt );
use Getopt::Long qw( GetOptions );

my $method = 'nlst';

GetOptions(
  'l' => sub { $method = 'list' },
);

my $ftp = AnyEvent::FTP::Client->new;

my $uri = shift;

unless(defined $uri)
{
  say STDERR "usage: perl fls.pl URL\n";
  exit 2;
}

$uri = URI->new($uri);

unless($uri->scheme eq 'ftp')
{
  say STDERR "only FTP URL accpeted";
  exit 2;
}

unless(defined $uri->password)
{
  $uri->password(prompt('p', 'Password: ', '', ''));
  say '';
}

my $path = $uri->path;
$uri->path('');

$ftp->connect($uri);

say $_ for @{ $ftp->$method($path)->recv };
