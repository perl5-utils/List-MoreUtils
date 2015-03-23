#! perl

use strict;
use warnings;

use Test::More;
BEGIN {
  $] >= 5.008 or plan skip_all => "Test::Pod::Coverage requires perl 5.8";
}
use Test::Pod::Coverage;
use Pod::Coverage;

my @modules = all_modules();
foreach my $module (@modules) {
   next if ($module =~ m/[^:]+::PP$/ );
   pod_coverage_ok($module);
}

done_testing();
