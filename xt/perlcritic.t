#!perl

use strict;
use warnings;

use Test::More;
use Test::Perl::Critic;

Test::Perl::Critic->import(-profile => 'xt/perlcritic.rc');
all_critic_ok();
