#!perl

use lib ("t/lib");
$ENV{LIST_MOREUTILS_PP} = 1;
END { delete $ENV{LIST_MOREUTILS_PP} } # for VMS

require LMU::Test::XS;

LMU::Test::XS->run_tests;

