#!perl

use strict;
use warnings;

use Test::More;
BEGIN {
  $] >= 5.008 or plan skip_all => "Test::CheckManifest requires perl 5.8";
}
use Test::CheckManifest;

ok_manifest();
