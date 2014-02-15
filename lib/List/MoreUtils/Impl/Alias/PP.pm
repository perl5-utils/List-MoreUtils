package List::MoreUtils::Impl::Alias::PP;

use strict;
use warnings;

# Use pure scalar boolean return values for compatibility with XS
sub any (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 1 if $f->();
    }
    return 0;
}

sub all (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 0 unless $f->();
    }
    return 1;
}

sub none (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 0 if $f->();
    }
    return 1;
}

sub notall (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 1 unless $f->();
    }
    return 0;
}

1;
