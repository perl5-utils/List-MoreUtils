package LMU::Test::Tassilo::Import;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", qw(any all none notall true false
              firstidx lastidx
              insert_after insert_after_string
              apply indexes
              after after_incl before before_incl
              firstval lastval
              each_array each_arrayref
              pairwise natatime
              mesh uniq
              minmax part
              bsearch) );
    done_testing();
}

1;
