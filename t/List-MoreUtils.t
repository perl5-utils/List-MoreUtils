use Test;
BEGIN { plan tests => 42 };

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

# insert_after
{
    my @list = qw/This is a list/;
    insert_after { $_ eq "a" } "longer" => @list;
    ok(join(' ', @list), "This is a longer list");
    insert_after { 0 } "bla" => @list;
    ok(join(' ', @list), "This is a longer list");
    insert_after { $_ eq "list" } "!" => @list;
    ok(join(' ', @list), "This is a longer list !");
    @list = (qw/This is/, undef, qw/list/);
    insert_after { !defined($_) } "longer" => @list;
    $list[2] = "a";
    ok(join(' ', @list), "This is a longer list");
}

# insert_after_string
{
    my @list = qw/This is a list/;
    insert_after_string "a", "longer" => @list;
    ok(join(' ', @list), "This is a longer list");
    @list = (undef, qw/This is a list/);
    insert_after_string "a", "longer", @list;
    shift @list;
    ok(join(' ', @list), "This is a longer list");
    @list = ("This\0", "is\0", "a\0", "list\0");
    insert_after_string "a\0", "longer\0", @list;
    ok(join(' ', @list), "This\0 is\0 a\0 longer\0 list\0");
}
