package LMU::Test::Alias::Load;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", ":alias" );
    done_testing();
}

1;
