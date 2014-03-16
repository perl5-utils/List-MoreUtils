package LMU::Test::Modern::Load;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", ":modern" );
    done_testing();
}

1;
