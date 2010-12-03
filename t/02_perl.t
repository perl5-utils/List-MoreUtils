#!/usr/bin/perl

use strict;
BEGIN {
    $|  = 1;
    $^W = 1;
    $ENV{LIST_MOREUTILS_PP} = 1;
};

use t::lib::Test;

t::lib::Test->run;
