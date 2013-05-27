use strict;
use Test::More;
use Test::LeakTrace;
use Groonga::Console;
use File::Spec;
use FindBin q($Bin);

my $TIMES = 100;
my $STEP = $TIMES / 10;
my $db = File::Spec->catdir($Bin, 'data/groonga');

sub tests_for {
    my ( $label, $db ) = @_;

    subtest "$TIMES times creation of $label DB" => sub {
        my $ok = 0;
        for ( 1..$TIMES ) {
            my $g = $db ? Groonga::Console->new($db) : Groonga::Console->new;
            $ok++ if $g;
            diag "Tested $_ times" unless $_ % $STEP;
        }
        is $ok, $TIMES, "Created count";

        no_leaks_ok {
            for ( 1..$TIMES ) {
                my $g = $db ? Groonga::Console->new($db) : Groonga::Console->new;
            }
        };
    };
}

tests_for('in-memory');
tests_for('file-system', $db);

done_testing;