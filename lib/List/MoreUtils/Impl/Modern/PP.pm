package List::MoreUtils::Impl::Modern::PP;

use strict;
use warnings;

sub any (&@) {
    my $f = shift;
    foreach ( @_ ) {
        $f->() and return 1;
    }
    return 0;
}

sub all (&@) {
    my $f = shift;
    foreach ( @_ ) {
        $f->() or return 0;
    }
    return 1;
}

sub none (&@) {
    my $f = shift;
    foreach ( @_ ) {
        $f->() and return 0;
    }
    return 1;
}

sub notall (&@) {
    my $f = shift;
    foreach ( @_ ) {
        $f->() or return 1;
    }
    return 0;
}

1;
