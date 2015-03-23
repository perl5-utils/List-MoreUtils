#!perl

use strict;
use warnings;

## in a separate test file
use Test::More;

BEGIN {
  $] >= 5.008 or plan skip_all => "Test::Spelling requires perl 5.8";
}
use Test::Spelling;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__END__
