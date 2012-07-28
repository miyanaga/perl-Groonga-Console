# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Groonga-Console.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More;
BEGIN { use_ok('Groonga::Console') };

my $g = Groonga::Console->new;
$g->execute('status');
my @logs = $g->logs;
is scalar @logs, 2;
like $logs[0], qr/>status/;
like $logs[1], qr/rc=0/;

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

done_testing;
