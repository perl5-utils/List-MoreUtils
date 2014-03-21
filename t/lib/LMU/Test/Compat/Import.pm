package LMU::Test::Compat::Import;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;
require List::MoreUtils;

sub run_tests
{
    test_compat();

    done_testing();
}

sub test_compat
{
    my %groups = (List::MoreUtils->_export_tags, List::MoreUtils->_export_alias_names);
    my %funcs = map {$_ => 1} map { @{$_} } values %groups;
    foreach my $func (keys %funcs)
    {
	ok(List::MoreUtils->can($func), "can $func" );
    }
}

1;
