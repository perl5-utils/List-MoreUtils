package LMU::Test::XS;

use strict;

BEGIN
{
    $| = 1;
}

use Test::More;
use List::MoreUtils;

sub run_tests
{
    test_xs();
    done_testing();
}

sub test_xs
{
    defined $ENV{LIST_MOREUTILS_PP}
      or plan skip_all => "No dedicated test for XS/PP - but can't detect configure time settings at tets runtime";
    is( List::MoreUtils::_XScompiled, 0 + !$ENV{LIST_MOREUTILS_PP}, "_XScompiled" );
}

1;
