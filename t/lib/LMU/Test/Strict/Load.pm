package LMU::Test::Strict::Load;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", ":strict" );
    done_testing();
}

1;
