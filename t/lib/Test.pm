package t::lib::Test;

use 5.00503;
use strict;
use Test;





######################################################################
# Test code intentionally ignorant of implementation (Pure Perl or XS)

sub test_zip {
    my @x = qw/a b c d/;
    my @y = qw/1 2 3 4/;
    my @z = List::MoreUtils::zip @x, @y;
    ok(arrayeq(\@z, ['a', 1, 'b', 2, 'c', 3, 'd', 4]));

    my @a = ('x');
    my @b = ('1', '2');
    my @c = qw/zip zap zot/;
       @z = List::MoreUtils::zip @a, @b, @c;
    ok(arrayeq(\@z, ['x', 1, 'zip', undef, 2, 'zap', undef, undef, 'zot']));

    @a = (1 .. 10);
    my @d;
    $#d = 9; # make array with holes
    @z = List::MoreUtils::zip @a, @d;
    ok(arrayeq(\@z, [1, undef, 2, undef, 3, undef, 4, undef, 5, undef, 
                     6, undef, 7, undef, 8, undef, 9, undef, 10, undef]));
}

sub test_uniq {
    my @a = map { (1 .. 10000) } 0 .. 1;
    my @u = List::MoreUtils::uniq @a;
    ok(arrayeq(\@u, [1 .. 10000]));
    my $u = List::MoreUtils::uniq @a;
    ok(10000, $u);
}

sub test_part {
    my @list = 1 .. 12;
    my $i    = 0;
    my @part = List::MoreUtils::part { $i++ % 3 } @list;
    ok(arrayeq($part[0], [ 1, 4, 7, 10 ]));
    ok(arrayeq($part[1], [ 2, 5, 8, 11 ]));
    ok(arrayeq($part[2], [ 3, 6, 9, 12 ]));

    @part = List::MoreUtils::part { 3 } @list;
    ok(!defined $part[0]);
    ok(!defined $part[1]);
    ok(!defined $part[2]); 
    ok(arrayeq($part[3], [ 1 .. 12 ]));

    eval {
        @part = List::MoreUtils::part { -1 } @list;
    };
    ok($@ =~ /^Modification of non-creatable array value attempted, subscript -1/);

    $i = 0;
    @part = List::MoreUtils::part { $i++ == 0 ? 0 : -1 } @list;
    ok(arrayeq($part[0], [ 1 .. 12 ]));

    local $^W = 0;
    @part = List::MoreUtils::part { undef } @list;
    ok(arrayeq($part[0], [ 1 .. 12 ]));

    @part = List::MoreUtils::part { 100_000 } @list;
    ok(arrayeq($part[100_000], [ @list ]));
    ok(!defined $part[0]);
    ok(!defined $part[@part/2]);
    ok(!defined $part[99_999]);

    # Changing the list in place used to destroy
    # its elements due to a wrong refcnt
    @list = 1 .. 10;
    @list = List::MoreUtils::part { $_ } @list;
    for (1 .. 10) {
        ok(arrayeq($list[$_], [ $_ ]));
    }
}





######################################################################
# Support Functions

sub arrayeq {
    local $^W = 0;
    my ($ary1, $ary2) = @_;
    return 0 if @$ary1 != @$ary2;
    for (0 .. $#$ary1) {
        if ($ary1->[$_] ne $ary2->[$_]) {
            local $" = ", ";
            warn "(@$ary1) != (@$ary2)\n";
            return 0;
        }
    }
    return 1;
}

1;
