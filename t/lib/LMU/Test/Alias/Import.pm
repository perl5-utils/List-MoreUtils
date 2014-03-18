package LMU::Test::Alias::Import;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;

sub run_tests {
    use_ok( "List::MoreUtils", qw(any all none notall) );
    done_testing();
}

1;
