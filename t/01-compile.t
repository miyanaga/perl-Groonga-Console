# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Groonga-Console.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More;
use_ok('Groonga::Console');

my $g = Groonga::Console->new;
ok $g;

my $res = $g->execute('status');
ok $res;

done_testing;
