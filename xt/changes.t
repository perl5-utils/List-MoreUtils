#!perl

use strict;
use warnings;

use Test::More;

BEGIN
{
    $] >= 5.010 or plan skip_all => "CPAN::Changes requires perl 5.10";
}
use Test::CPAN::Changes;

changes_ok();
