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
ARRAYn
Anno
AnnoCPAN
Branno
EXPR
Filmer
Inkster
Jens
KEYFUNC
MULTICALL
McCauley
Muey
Parseval
Purkis
Rabbitson
Rehsack
Rezic
Roode
Siegel
Signes
Slaven
Summersault
TODO
Tassilo
Tatham
Thegler
bsearchidx
de
firstidx
firstres
firstval
glitchy
lastidx
lastres
lastval
listify
minmax
natatime
notall
onlyidx
onlyres
onlyval
refactor
rehsackATcpan
thusly
uniq
von
