use strict;
use warnings;
use Test::More tests => 1;
use AnyEvent;

pass 'pass';
diag AnyEvent::detect();
