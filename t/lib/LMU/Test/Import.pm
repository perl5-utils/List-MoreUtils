package LMU::Test::Import;

use strict;

BEGIN
{
    $| = 1;
}

use Test::More;

sub run_tests
{
    use_ok(
        "List::MoreUtils", qw(any all none notall
          any_u all_u none_u notall_u
          true false firstidx lastidx
          insert_after insert_after_string
          apply indexes
          after after_incl before before_incl
          firstval lastval
          each_array each_arrayref
          pairwise natatime
          mesh uniq
          minmax part
          bsearch
          sort_by nsort_by
          first_index last_index first_value last_value zip distinct)
    );
    done_testing();
}

1;

