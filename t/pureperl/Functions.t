#!perl

use lib ("t/lib");
$ENV{LIST_MOREUTILS_PP} = 1;
END { delete $ENV{LIST_MOREUTILS_PP} } # for VMS

require LMU::Test::Functions;

LMU::Test::Functions->run_tests;

