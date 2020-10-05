#!perl

use strict;
use warnings;

## in a separate test file
use Test::More;

BEGIN
{
    $] >= 5.008 or plan skip_all => "Test::Spelling requires perl 5.8";
}
use Test::Spelling;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__END__
Anno
AnnoCPAN
arrayify
ARRAYn
binsert
Branno
bremove
bsearchidx
de
EXPR
Filmer
firstidx
firstres
firstval
glitchy
Inkster
Jens
KEYFUNC
Knop
lastidx
lastres
lastval
listcmp
listify
McCauley
MetaCPAN
min
minmax
minmaxstr
Muey
MULTICALL
natatime
notall
onlyidx
onlyres
onlyval
org
Parseval
PP
progressional
Purkis
Rabbitson
refactor
Rehsack
rehsackATcpan
Rezic
Roode
RT
Siegel
Signes
Slaven
slideatatime
Summersault
Tassilo
Tatham
Thegler
thusly
TODO
uniq
von
