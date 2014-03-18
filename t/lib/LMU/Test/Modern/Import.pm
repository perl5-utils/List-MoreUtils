package LMU::Test::Modern::Import;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", qw(any all none notall
              sort_by nsort_by) );
    done_testing();
}

1;
