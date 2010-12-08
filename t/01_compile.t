#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 2;

use_ok( 'List::MoreUtils' );
use_ok( 't::lib::Test'    );
