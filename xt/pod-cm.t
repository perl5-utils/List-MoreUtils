#! perl

use strict;
use warnings;

use Test::More;

use Test::Pod::Spelling::CommonMistakes qw(all_pod_files_ok);

all_pod_files_ok();

1;
