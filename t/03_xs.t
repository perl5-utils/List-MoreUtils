#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
    $ENV{LIST_MOREUTILS_PP} = 0;
};

require t::lib::Test;

t::lib::Test->run;
