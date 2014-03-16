package LMU::Test::Tassilo::Load;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", ":tassilo" );
    done_testing();
}

1;
