package LMU::Test::Relax::Load;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", ":relax" );
    done_testing();
}

1;
