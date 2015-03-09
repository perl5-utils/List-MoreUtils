package LMU::Test::ab;

use strict;

BEGIN
{
    $| = 1;
}

use Test::More;
use List::MoreUtils 'pairwise';

sub run_tests
{
    test_ab();
    done_testing();
}

sub test_ab
{
    my @A = ( 1, 2, 3, 4, 5 );
    my @B = ( 2, 4, 6, 8, 10 );
    my @C = pairwise { $a + $b } @A, @B;
    is_deeply( \@C, [ 3, 6, 9, 12, 15 ], "pw1" );
}

1;
