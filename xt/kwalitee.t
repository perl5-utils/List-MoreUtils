#!perl

## in a separate test file

use strict;
use warnings;

use Test::More;
use Test::Kwalitee 'kwalitee_ok';

kwalitee_ok();

done_testing;
