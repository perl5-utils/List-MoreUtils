#! perl

use strict;
use warnings;

use Test::More;
use Test::Pod::Coverage;
use Pod::Coverage;

my @modules = all_modules();
foreach my $module (@modules) {
   next if ($module =~ m/[^:]+::PP$/ );
   pod_coverage_ok($module);
}

done_testing();
