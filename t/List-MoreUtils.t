use Test;
BEGIN { plan tests => 35 };

use List::MoreUtils qw/:all/;

ok(1); 

# any
{
    my @list = (1 .. 10000);
    ok(any { $_ == 5000 } @list);
    ok(any { $_ == 5000 } 1 .. 10000);
    ok(any { defined } @list);
    ok(!any { !defined } @list);
    ok(any { !defined } undef);
    ok(!defined(any { }));
}

# all
{
    my @list = (1 .. 10000);
    ok(all { defined } @list);
    ok(all { $_ > 0 } @list);
    ok(!all { $_ < 5000 } @list);
    ok(!defined all { } );
}

# none
{
    my @list = (1 .. 10000);
    ok(none { !defined } @list);
    ok(none { $_ > 10000 } @list);
    ok(!none { defined } @list);
    ok(!defined none { });
}

# notall
{
    my @list = (1 .. 10000);
    ok(notall { !defined } @list);
    ok(notall { $_ < 10000 } @list);
    ok(!notall { $_ <= 10000 } @list);
    ok(!defined notall { });
}

# true
{
    my @list = (1 .. 10000);
    ok(10000, true { defined } @list);
    ok(0, true { !defined } @list);
    ok(1, true { $_ == 10000 } @list);
    ok(!true { });
}

# false
{
    my @list = (1 .. 10000);
    ok(10000, false { !defined } @list);
    ok(0, false { defined } @list);
    ok(1, false { $_ > 1 } @list);
    ok(!false { });
}

# firstidx
{
    my @list = (1 .. 10000);
    ok(4999, firstidx { $_ >= 5000 } @list);
    ok(-1, firstidx { !defined } @list);
    ok(0, firstidx { defined } @list);
    ok(-1, firstidx { });
}

# lastidx
{
    my @list = (1 .. 10000);
    ok(9999, lastidx { $_ >= 5000 } @list);
    ok(-1, lastidx { !defined } @list);
    ok(9999, lastidx { defined } @list);
    ok(-1, lastidx { });
}
