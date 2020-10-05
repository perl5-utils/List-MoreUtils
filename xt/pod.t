#!perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    $] >= 5.008 or plan skip_all => "Test::Pod requires perl 5.8";
}
use Test::Pod;

all_pod_files_ok();
