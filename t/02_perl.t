#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
}
use Test::More tests => 149;

# Load the library
BEGIN { 
    $ENV{LIST_MOREUTILS_PP} = 1;
};
use List::MoreUtils qw/:all/;

# Execute the common test suite
use t::lib::Test;
t::lib::Test->run;
