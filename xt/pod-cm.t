#! perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    $] >= 5.010 or plan skip_all => "Test::Pod::Spelling::CommonMistakes requires perl 5.10";
}
use Test::Pod::Spelling::CommonMistakes qw(all_pod_files_ok);

all_pod_files_ok();

1;
