package t::lib::Test;

use 5.00503;
use strict;
use Test::More;
use List::MoreUtils ':all';

# Run all tests
sub run {
    test_any();
    test_all();
    test_none();
    test_notall();
    test_true();
    test_false();
    test_firstidx();
    test_lastidx();
    test_insert_after();
    test_insert_after_string();
    test_apply();
    test_indexes();
    test_before();
    test_before_incl();
    test_after();
    test_after_incl();
    test_firstval();
    test_lastval();
    test_each_array();
    test_pairwise();
    test_natatime();
    test_zip();
    test_mesh();
    test_uniq();
    test_part();
    test_minmax();
}





######################################################################
# Test code intentionally ignorant of implementation (Pure Perl or XS)

sub test_any {
    my @list = ( 1 .. 10000 );
    ok( any { $_ == 5000 } @list );
    ok( any { $_ == 5000 } 1 .. 10000 );
    ok( any { defined } @list );
    ok( ! any { ! defined } @list );
    ok( any { ! defined } undef );
    ok( ! defined(any { }) );
}

sub test_all {
    my @list = ( 1 .. 10000 );
    ok( all { defined } @list );
    ok( all { $_ > 0 } @list );
    ok( ! all { $_ < 5000 } @list );
    ok( ! defined all { } );
}

sub test_none {
    my @list = ( 1 .. 10000 );
    ok( none { ! defined } @list );
    ok( none { $_ > 10000 } @list );
    ok( ! none { defined } @list );
    ok( ! defined none { } );
}

sub test_notall {
    my @list = ( 1 .. 10000 );
    ok( notall { ! defined } @list );
    ok( notall { $_ < 10000 } @list );
    ok( ! notall { $_ <= 10000 } @list );
    ok( ! defined notall { } );
}

sub test_true {
    my @list = ( 1 .. 10000 );
    is( 10000, true { defined } @list );
    is( 0, true { ! defined } @list );
    is( 1, true { $_ == 10000 } @list );
    ok( ! true { } );
}

sub test_false {
    my @list = ( 1 .. 10000 );
    is( 10000, false { ! defined } @list );
    is( 0, false { defined } @list );
    is( 1, false { $_ > 1 } @list );
    ok( ! false { } );
}

sub test_firstidx {
    my @list = ( 1 .. 10000 );
    is( 4999, firstidx { $_ >= 5000 } @list );
    is( -1, firstidx { ! defined } @list );
    is( 0, firstidx { defined } @list );
    is( -1, firstidx { } );

    # Test aliases
    is( 4999, first_index { $_ >= 5000 } @list );
    is( -1, first_index { ! defined } @list );
    is( 0, first_index { defined } @list );
    is( -1, first_index { } );
}

sub test_lastidx {
    my @list = ( 1 .. 10000 );
    is( 9999, lastidx { $_ >= 5000 } @list );
    is( -1, lastidx { ! defined } @list );
    is( 9999, lastidx { defined } @list );
    is( -1, lastidx { } );

    # Test aliases
    is( 9999, last_index { $_ >= 5000 } @list );
    is( -1, last_index { ! defined } @list );
    is( 9999, last_index { defined } @list );
    is( -1, last_index { } );
}

sub test_insert_after {
    my @list = qw/This is a list/;
    insert_after { $_ eq "a" } "longer" => @list;
    is( join(' ', @list), "This is a longer list" );
    insert_after { 0 } "bla" => @list;
    is( join(' ', @list), "This is a longer list" );
    insert_after { $_ eq "list" } "!" => @list;
    is( join(' ', @list), "This is a longer list !" );
    @list = ( qw/This is/, undef, qw/list/ );
    insert_after { ! defined($_) } "longer" => @list;
    $list[2] = "a";
    is( join(' ', @list), "This is a longer list" );
}

sub test_insert_after_string {
    my @list = qw/This is a list/;
    insert_after_string "a", "longer" => @list;
    is( join(' ', @list), "This is a longer list" );
    @list = ( undef, qw/This is a list/ );
    insert_after_string "a", "longer", @list;
    shift @list;
    is( join(' ', @list), "This is a longer list" );
    @list = ( "This\0", "is\0", "a\0", "list\0" );
    insert_after_string "a\0", "longer\0", @list;
    is( join(' ', @list), "This\0 is\0 a\0 longer\0 list\0" );
}

sub test_apply {
    my @list  = ( 0 .. 9 );
    my @list1 = apply { $_++ } @list;
    ok( arrayeq(\@list, [0..9]) );
    ok( arrayeq(\@list1, [1..10]) );

    @list = ( " foo ", " bar ", "     ", "foobar" );
    @list1 = apply { s/^\s+|\s+$//g } @list;
    ok( arrayeq(\@list, [" foo ", " bar ", "     ", "foobar"]) );
    ok( arrayeq(\@list1, ["foo", "bar", "", "foobar"]) );

    my $item = apply { s/^\s+|\s+$//g } @list;
    is( $item, "foobar" );

    ok( ! defined apply {} );
}

sub test_indexes {
    my @x = indexes { $_ > 5 }  4..9;
    ok( arrayeq( \@x, [ 2..5 ] ) );
    @x = indexes { $_ > 5 }  1..4;  
    ok( ! @x );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before {
    my @x = before {$_ % 5 == 0} 1..9;    
    ok( arrayeq(\@x, [1, 2, 3, 4]) );
    @x = before { /b/ } my @dummy = qw/bar baz/;
    ok( ! @x );
    @x = before { /f/ } @dummy = qw/bar baz foo/;
    ok( arrayeq(\@x, [  qw/bar baz/ ]) );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before_incl {
    my @x = before_incl {$_ % 5 == 0} 1..9;
    ok( arrayeq(\@x, [1, 2, 3, 4, 5]) );
    @x = before_incl { /foo/ } my @dummy = qw/bar baz/;
    ok( arrayeq(\@x, [ qw/bar baz/ ]) );
    @x = before_incl { /f/ } @dummy = qw/bar baz foo/;
    ok( arrayeq(\@x, [ qw/bar baz foo/ ]) );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after {
    my @x = after { $_ % 5 == 0 } 1..9;
    ok( arrayeq(\@x, [6,7,8,9]) );
    @x = after { /foo/ } my @dummy = qw/bar baz/;
    ok( ! @x );
    @x = after { /b/ } @dummy = qw/bar baz foo/;
    ok( arrayeq(\@x, [ qw/baz foo/ ]) );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after_incl {
    my @x = after_incl { $_ % 5 == 0 } 1..9;
    ok( arrayeq(\@x, [5, 6, 7, 8, 9]) );
    @x = after_incl { /foo/ } my @dummy = qw/bar baz/;
    ok( ! @x );
    @x = after_incl { /b/ } @dummy = qw/bar baz foo/;
    ok( arrayeq(\@x, [ qw/bar baz foo/ ]) );
}

sub test_firstval {
    my $x = firstval { $_ > 5 }  4..9; 
    is( $x, 6 );
    $x = firstval { $_ > 5 }  1..4;
    ok( ! defined $x );

    # Test aliases
    $x = first_value { $_ > 5 }  4..9; 
    is( $x, 6 );
    $x = first_value { $_ > 5 }  1..4;
    ok( ! defined $x );
}

sub test_lastval {
    my $x = lastval { $_ > 5 }  4..9;
    is( $x, 9 );
    $x = lastval { $_ > 5 }  1..4;
    ok( ! defined $x );

    # Test aliases
    $x = last_value { $_ > 5 }  4..9;  
    is( $x, 9 );
    $x = last_value { $_ > 5 }  1..4;
    ok( ! defined $x );
}

sub test_each_array {
    SCOPE: {
        my @a  = ( 7, 3, 'a', undef, 'r' );
        my @b  = qw{ a 2 -1 x };
        my $it = each_array @a, @b;
        my (@r, @idx);
        while ( my ($a, $b) = $it->() ) {
            push @r, $a, $b;
            push @idx, $it->('index');
        }

        # Do I segfault? I shouldn't. 
        $it->();

        ok( arrayeq( \@r, [ 7, 'a', 3, 2, 'a', -1, undef, 'x', 'r', undef ] ) );
        ok( arrayeq( \@idx, [ 0..4 ] ) );

        # Testing two iterators on the same arrays in parallel
        @a = ( 1, 3, 5 );
        @b = ( 2, 4, 6 );
        my $i1 = each_array @a, @b;
        my $i2 = each_array @a, @b;
        @r = ();
        while ( my ($a, $b) = $i1->() and my ($c, $d) = $i2->() ) {
            push @r, $a, $b, $c, $d;
        }
        ok( arrayeq( \@r, [ 1, 2, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6 ] ) );

        # Input arrays must not be modified
        ok( arrayeq( \@a, [ 1, 3, 5 ] ) );
        ok( arrayeq( \@b, [ 2, 4, 6 ] ) );

        # This used to give "semi-panic: attempt to dup freed string"
        # See: <news:1140827861.481475.111380@z34g2000cwc.googlegroups.com>
        my $ea = each_arrayref( [ 1 .. 26 ], [ 'A' .. 'Z' ] );
        (@a, @b) = ();
        while ( my ($a, $b) = $ea->() ) {
            push @a, $a; push @b, $b;
        }
        ok( arrayeq( \@a, [ 1 .. 26 ] ) );
        ok( arrayeq( \@b, [ 'A' .. 'Z' ] ) );

        # And this even used to dump core
        my @nums = 1 .. 26;
        $ea = each_arrayref( \@nums, [ 'A' .. 'Z' ] );
        (@a, @b) = ();
        while ( my ($a, $b) = $ea->() ) {
            push @a, $a; push @b, $b;
        }
        ok( arrayeq( \@a, [ 1 .. 26 ] ) );
        ok( arrayeq( \@a, \@nums ) );
        ok( arrayeq( \@b, ['A' .. 'Z' ] ) );
    }

    SCOPE: {
        my @a = ( 7, 3, 'a', undef, 'r' );
        my @b = qw/a 2 -1 x/;

        my $it = each_arrayref \@a, \@b;
        my (@r, @idx);
        while ( my ($a, $b) = $it->() ) {
            push @r, $a, $b;
            push @idx, $it->('index');
        }

        # Do I segfault? I shouldn't. 
        $it->();

        ok( arrayeq( \@r, [ 7, 'a', 3, 2, 'a', -1, undef, 'x', 'r', undef ] ) );
        ok( arrayeq( \@idx, [ 0..4 ] ) );

        # Testing two iterators on the same arrays in parallel
        @a = (1, 3, 5);
        @b = (2, 4, 6);
        my $i1 = each_array @a, @b;
        my $i2 = each_array @a, @b;
        @r = ();
        while ( my ($a, $b) = $i1->() and my ($c, $d) = $i2->() ) {
            push @r, $a, $b, $c, $d;
        }
        ok( arrayeq( \@r, [ 1, 2, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6 ] ) );

        # Input arrays must not be modified
        ok( arrayeq( \@a, [ 1, 3, 5 ] ) );
        ok( arrayeq( \@b, [ 2, 4, 6 ] ) );
    }
}

sub test_pairwise {
    my @a = (1, 2, 3, 4, 5);
    my @b = (2, 4, 6, 8, 10);
    my @c = pairwise { $a + $b } @a, @b;
    is( arrayeq( \@c, [ 3, 6, 9, 12, 15 ] ), 1, "pw1" );

    @c = pairwise { $a * $b } @a, @b; # returns (2, 8, 18)
    is( arrayeq( \@c, [ 2, 8, 18, 32, 50 ] ), 1, "pw2" );

    # Did we modify the input arrays?
    is( arrayeq( \@a, [ 1, 2, 3, 4, 5 ] ), 1, "pw3" );
    is( arrayeq( \@b, [ 2, 4, 6, 8, 10 ] ), 1, "pw4" );

    # $a and $b should be aliases: test
    @b = @a = (1, 2, 3);
    @c = pairwise { $a++; $b *= 2 } @a, @b;
    is( arrayeq( \@a, [ 2, 3, 4 ] ), 1, "pw5" );
    is( arrayeq( \@b, [ 2, 4, 6 ] ), 1, "pw6" );
    is( arrayeq( \@c, [ 2, 4, 6 ] ), 1, "pw7" );

    # Test this one more thoroughly: the XS code looks flakey
    # correctness of pairwise_perl proved by human auditing. :-)
    sub pairwise_perl (&\@\@) {
        no strict;
        my $op = shift;
        local (*A, *B) = @_;    # syms for caller's input arrays

        # Localise $a, $b
        my ($caller_a, $caller_b) = do {
            my $pkg = caller();
            \*{$pkg.'::a'}, \*{$pkg.'::b'};
        };

        # Loop iteration limit
        my $limit = $#A > $#B? $#A : $#B;

        # This map expression is also the return value.
        local(*$caller_a, *$caller_b);
        map {
            # Assign to $a, $b as refs to caller's array elements
            (*$caller_a, *$caller_b) = \($A[$_], $B[$_]);
            $op->();    # perform the transformation
        } 0 .. $limit;
    }

    (@a, @b) = ();
    push @a, int rand(1000) for 0 .. rand(1000);
    push @b, int rand(1000) for 0 .. rand(1000);
    local $^W = 0;
    my @res1 = pairwise {$a+$b} @a, @b;
    my @res2 = pairwise_perl {$a+$b} @a, @b;
    ok( arrayeq(\@res1, \@res2) );

    @a = qw/a b c/;
    @b = qw/1 2 3/;
    @c = pairwise { ($a, $b) } @a, @b;
    ok( arrayeq( \@c, [ qw/a 1 b 2 c 3/ ] ) ); # 88

    # Test that a die inside the code-reference will not be trapped
    eval { pairwise { die "I died\n" } @a, @b };
    is( $@, "I died\n" );
}

sub test_natatime {
    my @x = ( 'a'..'g' );
    my $it = natatime 3, @x;
    my @r;
    local $" = " ";
    while ( my @vals = $it->() ) {
        push @r, "@vals";
    }
    is( arrayeq( \@r, [ 'a b c', 'd e f', 'g' ] ), 1, "natatime1" );

    my @a = ( 1 .. 1000 );
    $it = natatime 1, @a;
    @r = ();
    while ( my @vals = &$it ) {
        push @r, @vals;
    }
    is( arrayeq( \@r, \@a ), 1, "natatime2" );
}

sub test_zip {
    my @x = qw/a b c d/;
    my @y = qw/1 2 3 4/;
    my @z = zip @x, @y;
    ok( arrayeq(\@z, ['a', 1, 'b', 2, 'c', 3, 'd', 4]) );

    my @a = ( 'x' );
    my @b = ( '1', '2' );
    my @c = qw/zip zap zot/;
       @z = zip @a, @b, @c;
    ok( arrayeq( \@z, [ 'x', 1, 'zip', undef, 2, 'zap', undef, undef, 'zot' ] ) );

    @a = ( 1 .. 10 );
    my @d;
    $#d = 9; # make array with holes
    @z = zip @a, @d;
    ok( arrayeq( \@z, [ 1, undef, 2, undef, 3, undef, 4, undef, 5, undef, 
                     6, undef, 7, undef, 8, undef, 9, undef, 10, undef ] ) );
}

sub test_mesh {
    my @x = qw/a b c d/;
    my @y = qw/1 2 3 4/;
    my @z = mesh @x, @y;
    ok( arrayeq( \@z, [ 'a', 1, 'b', 2, 'c', 3, 'd', 4 ] ) );

    my @a = ('x');
    my @b = ('1', '2');
    my @c = qw/zip zap zot/;
    @z = mesh @a, @b, @c;
    ok( arrayeq( \@z, [ 'x', 1, 'zip', undef, 2, 'zap', undef, undef, 'zot' ] ) );

    @a = ( 1 .. 10 );
    my @d;
    $#d = 9; # make array with holes
    @z = mesh @a, @d;
    ok( arrayeq( \@z, [ 1, undef, 2, undef, 3, undef, 4, undef, 5, undef, 
                     6, undef, 7, undef, 8, undef, 9, undef, 10, undef ] ) );
}

sub test_uniq {
    my @a = map { ( 1 .. 1000 ) } 0 .. 1;
    my @u = uniq @a;
    ok( arrayeq( \@u, [ 1 .. 1000 ] ) );
    my $u = uniq @a;
    is( 1000, $u );
}

sub test_part {
    my @list = 1 .. 12;
    my $i    = 0;
    my @part = part { $i++ % 3 } @list;
    ok( arrayeq($part[0], [ 1, 4, 7, 10 ]) );
    ok( arrayeq($part[1], [ 2, 5, 8, 11 ]) );
    ok( arrayeq($part[2], [ 3, 6, 9, 12 ]) );

    @part = part { 3 } @list;
    ok( ! defined $part[0] );
    ok( ! defined $part[1] );
    ok( ! defined $part[2] ); 
    ok( arrayeq($part[3], [ 1 .. 12 ]) );

    eval {
        @part = part { -1 } @list;
    };
    ok( $@ =~ /^Modification of non-creatable array value attempted, subscript -1/ );

    $i = 0;
    @part = part { $i++ == 0 ? 0 : -1 } @list;
    ok( arrayeq($part[0], [ 1 .. 12 ]) );

    local $^W = 0;
    @part = part { undef } @list;
    ok( arrayeq($part[0], [ 1 .. 12 ]) );

    @part = part { 10000 } @list;
    ok( arrayeq($part[10000], [ @list ]) );
    ok( ! defined $part[0] );
    ok( ! defined $part[@part / 2] );
    ok( ! defined $part[9999] );

    # Changing the list in place used to destroy
    # its elements due to a wrong refcnt
    @list = 1 .. 10;
    @list = part { $_ } @list;
    foreach ( 1 .. 10 ) {
        ok( arrayeq($list[$_], [ $_ ]) );
    }
}

sub test_minmax {
    my @list = reverse 0 .. 10000;
    my ($min, $max) = minmax @list;
    is( $min, 0 );
    is( $max, 10000 );

    # Even number of elements
    push @list, 10001;
    ($min, $max) = minmax @list;
    is( $min, 0 );
    is( $max, 10001 );

    # Some floats
    @list = ( 0, -1.1, 3.14, 1 / 7, 10000, -10 / 3 );
    ($min, $max) = minmax @list;

    # Floating-point comparison cunningly avoided
    is( sprintf("%.2f", $min), "-3.33" );
    is( $max, 10000 );

    # Test with a single negative list value
    my $input = -1;
    ($min, $max) = minmax $input;
    is( $min, -1 );
    is( $max, -1 );

    # Confirm output are independant copies of input
    $input = 1;
    is( $min, -1 );
    is( $max, -1 );
    $min = 2;
    is( $max, -1 );
}





######################################################################
# Support Functions

sub arrayeq {
    local $^W = 0;
    my $left  = shift;
    my $right = shift;
    return 0 if @$left != @$right;
    foreach ( 0 .. $#$left ) {
        if ($left->[$_] ne $right->[$_]) {
            local $" = ", ";
            warn "(@$left) != (@$right)\n";
            return 0;
        }
    }
    return 1;
}

1;
