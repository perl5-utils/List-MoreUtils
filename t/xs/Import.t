#!perl

use lib ("t/lib");
$ENV{LIST_MOREUTILS_PP} = 0;
END { delete $ENV{LIST_MOREUTILS_PP} } # for VMS

require LMU::Test::Import;

LMU::Test::Import->run_tests;

