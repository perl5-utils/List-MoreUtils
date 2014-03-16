package LMU::Test::Alias::Funcs;

use 5.008001;

use strict;
#use warnings;

use Test::More;
use Test::LMU;
use List::MoreUtils ':alias';

# Run all tests
sub run_tests {
    test_any();
    test_all();
    test_none();
    test_notall();

    test_sort_by();
    test_nsort_by();

    done_testing();
}

sub test_any {
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( any { $_ == 5000 } @list );
    is_true( any { $_ == 5000 } 1 .. 10000 );
    is_true( any { defined } @list );
    is_false( any { not defined } @list );
    is_true( any { not defined } undef );
    is_false( any { } );

    leak_free_ok(any => sub {
        my $ok = any { $_ == 5000 } @list;
        my $ok2 = any { $_ == 5000 } 1 .. 10000;
    });
    leak_free_ok('any with a coderef that dies' => sub {
        # This test is from Kevin Ryde; see RT#48669
        eval { my $ok = any { die } 1 };
    });
}

sub test_all {
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( all { defined } @list );
    is_true( all { $_ > 0 } @list );
    is_false( all { $_ < 5000 } @list );
    is_true( all { } );

    leak_free_ok(all => sub {
        my $ok  = all { $_ == 5000 } @list;
        my $ok2 = all { $_ == 5000 } 1 .. 10000;
    });
}

sub test_none {
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( none { not defined } @list );
    is_true( none { $_ > 10000 } @list );
    is_false( none { defined } @list );
    is_true( none { } );

    leak_free_ok(none => sub {
        my $ok  = none { $_ == 5000 } @list;
        my $ok2 = none { $_ == 5000 } 1 .. 10000;
    });
}

sub test_notall {
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( notall { ! defined } @list );
    is_true( notall { $_ < 10000 } @list );
    is_false( notall { $_ <= 10000 } @list );
    is_false( notall { } );

    leak_free_ok(notall => sub {
        my $ok  = notall { $_ == 5000 } @list;
        my $ok2 = notall { $_ == 5000 } 1 .. 10000;
    });
}

sub test_sort_by {
    my @list = map { [$_] } 1 .. 100;
    is_deeply([sort_by { $_->[0] } @list], [map { [$_] } sort { $a cmp $b } 1..100]);
}

sub test_nsort_by {
    my @list = map { [$_] } 1 .. 100;
    is_deeply([nsort_by { $_->[0] } @list], [map { [$_] } sort { $a <=> $b } 1..100]);
}

1;
