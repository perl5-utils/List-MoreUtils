package LMU::Test::Functions;

use strict;
use warnings;

use Test::More;
use Test::LMU;
use Tie::Array ();
use List::MoreUtils ':all';

use Config;

my $have_scalar_util;
eval "use Scalar::Util qw(); \$have_scalar_util = 1;";

eval "use Storable qw();";
$@ or Storable->import(qw(freeze));
__PACKAGE__->can("freeze") or eval <<'EOFR';
use inc::latest 'JSON::PP';
use JSON::PP qw();
sub freeze {
    my $json = JSON::PP->new();
    $json->encode($_[0]);
}
EOFR

# Run all tests
sub run_tests
{
    test_any();
    test_all();
    test_none();
    test_notall();
    test_one();
    test_any_u();
    test_all_u();
    test_none_u();
    test_notall_u();
    test_one_u();
    test_true();
    test_false();
    test_firstidx();
    test_lastidx();
    test_onlyidx();
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
    test_onlyval();
    test_firstres();
    test_lastres();
    test_onlyres();
    test_each_array();
    test_pairwise();
    test_natatime();
    test_zip();
    test_mesh();
    test_uniq();
    test_singleton();
    test_part();
    test_minmax();
    test_bsearch();
    test_bsearchidx();

    done_testing();
}

######################################################################
# Test code intentionally ignorant of implementation (Pure Perl or XS)

# The any function should behave identically to
# !! grep CODE LIST
sub test_any_u
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( any_u  { $_ == 5000 } @list );
    is_true( any_u  { $_ == 5000 } 1 .. 10000 );
    is_true( any_u  { defined } @list );
    is_false( any_u { not defined } @list );
    is_true( any_u  { not defined } undef );
    is_undef( any_u {} );

    leak_free_ok(
        any_u => sub {
            my $ok  = any_u { $_ == 5000 } @list;
            my $ok2 = any_u { $_ == 5000 } 1 .. 10000;
        }
    );
    leak_free_ok(
        'any_u with a coderef that dies' => sub {
            # This test is from Kevin Ryde; see RT#48669
            eval {
                my $ok = any_u { die } 1;
            };
        }
    );
    is_dying( sub { &any_u( 42, 4711 ); } );
}

sub test_all_u
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( all_u  { defined } @list );
    is_true( all_u  { $_ > 0 } @list );
    is_false( all_u { $_ < 5000 } @list );
    is_undef( all_u {} );

    leak_free_ok(
        all_u => sub {
            my $ok  = all_u { $_ == 5000 } @list;
            my $ok2 = all_u { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &all_u( 42, 4711 ); } );
}

sub test_none_u
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( none_u  { not defined } @list );
    is_true( none_u  { $_ > 10000 } @list );
    is_false( none_u { defined } @list );
    is_undef( none_u {} );

    leak_free_ok(
        none_u => sub {
            my $ok  = none_u { $_ == 5000 } @list;
            my $ok2 = none_u { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &none_u( 42, 4711 ); } );
}

sub test_notall_u
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( notall_u  { !defined } @list );
    is_true( notall_u  { $_ < 10000 } @list );
    is_false( notall_u { $_ <= 10000 } @list );
    is_undef( notall_u {} );

    leak_free_ok(
        notall_u => sub {
            my $ok  = notall_u { $_ == 5000 } @list;
            my $ok2 = notall_u { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &notall_u( 42, 4711 ); } );
}

sub test_one_u
{
    # Normal cases
    my @list = ( 1 .. 300 );
    is_true( one_u  { 1 == $_ } @list );
    is_true( one_u  { 150 == $_ } @list );
    is_true( one_u  { 300 == $_ } @list );
    is_false( one_u { 0 == $_ } @list );
    is_false( one_u { 1 <= $_ } @list );
    is_false( one_u { !( 127 & $_ ) } @list );
    is_undef( one_u {} );

    leak_free_ok(
        one => sub {
            my $ok  = one_u { 150 <= $_ } @list;
            my $ok2 = one_u { 150 <= $_ } 1 .. 300;
        }
    );
    is_dying( sub { &one_u( 42, 4711 ); } );
}

sub test_true
{
    # The null set should return zero
    my $null_scalar = true {};
    my @null_list   = true {};
    is( $null_scalar, 0, 'true(null) returns undef' );
    is_deeply( \@null_list, [0], 'true(null) returns undef' );

    # Normal cases
    my @list = ( 1 .. 10000 );
    is( 10000, true { defined } @list );
    is( 0,     true { not defined } @list );
    is( 1,     true { $_ == 5000 } @list );

    leak_free_ok(
        true => sub {
            my $n  = true { $_ == 5000 } @list;
            my $n2 = true { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &true( 42, 4711 ); } );
}

sub test_false
{
    # The null set should return zero
    my $null_scalar = false {};
    my @null_list   = false {};
    is( $null_scalar, 0, 'false(null) returns undef' );
    is_deeply( \@null_list, [0], 'false(null) returns undef' );

    # Normal cases
    my @list = ( 1 .. 10000 );
    is( 10000, false { not defined } @list );
    is( 0,     false { defined } @list );
    is( 1,     false { $_ > 1 } @list );

    leak_free_ok(
        false => sub {
            my $n  = false { $_ == 5000 } @list;
            my $n2 = false { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &false( 42, 4711 ); } );
}

sub test_firstidx
{
    my @list = ( 1 .. 10000 );
    is( 4999, ( firstidx { $_ >= 5000 } @list ),  "firstidx" );
    is( -1,   ( firstidx { not defined } @list ), "invalid firstidx" );
    is( 0,    ( firstidx { defined } @list ),     "real firstidx" );
    is( -1, ( firstidx {} ), "empty firstidx" );

    # Test the alias
    is( 4999, first_index { $_ >= 5000 } @list );
    is( -1,   first_index { not defined } @list );
    is( 0,    first_index { defined } @list );
    is( -1, first_index {} );

    leak_free_ok(
        firstidx => sub {
            my $i  = firstidx { $_ >= 5000 } @list;
            my $i2 = firstidx { $_ >= 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &firstidx( 42, 4711 ); } );
}

sub test_lastidx
{
    my @list = ( 1 .. 10000 );
    is( 9999, lastidx { $_ >= 5000 } @list );
    is( -1,   lastidx { not defined } @list );
    is( 9999, lastidx { defined } @list );
    is( -1, lastidx {} );

    # Test aliases
    is( 9999, last_index { $_ >= 5000 } @list );
    is( -1,   last_index { not defined } @list );
    is( 9999, last_index { defined } @list );
    is( -1, last_index {} );

    leak_free_ok(
        lastidx => sub {
            my $i  = lastidx { $_ >= 5000 } @list;
            my $i2 = lastidx { $_ >= 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &lastidx( 42, 4711 ); } );
}

sub test_onlyidx
{
    my @list = ( 1 .. 300 );
    is( 0,   onlyidx { 1 == $_ } @list );
    is( 149, onlyidx { 150 == $_ } @list );
    is( 299, onlyidx { 300 == $_ } @list );
    is( -1,  onlyidx { 0 == $_ } @list );
    is( -1,  onlyidx { 1 <= $_ } @list );
    is( -1,  onlyidx { !( 127 & $_ ) } @list );

    # Test aliases
    is( 0,   only_index { 1 == $_ } @list );
    is( 149, only_index { 150 == $_ } @list );
    is( 299, only_index { 300 == $_ } @list );
    is( -1,  only_index { 0 == $_ } @list );
    is( -1,  only_index { 1 <= $_ } @list );
    is( -1,  only_index { !( 127 & $_ ) } @list );

    leak_free_ok(
        onlyidx => sub {
            my $ok  = onlyidx { 150 <= $_ } @list;
            my $ok2 = onlyidx { 150 <= $_ } 1 .. 300;
        }
    );
    is_dying( sub { &onlyidx( 42, 4711 ); } );
}

sub test_insert_after
{
    my @list = qw{This is a list};
    insert_after { $_ eq "a" } "longer" => @list;
    is( join( ' ', @list ), "This is a longer list" );
    insert_after { 0 } "bla" => @list;
    is( join( ' ', @list ), "This is a longer list" );
    insert_after { $_ eq "list" } "!" => @list;
    is( join( ' ', @list ), "This is a longer list !" );
    @list = ( qw{This is}, undef, qw{list} );
    insert_after { not defined($_) } "longer" => @list;
    $list[2] = "a";
    is( join( ' ', @list ), "This is a longer list" );

    leak_free_ok(
        insert_after => sub {
            @list = qw{This is a list};
            insert_after { $_ eq 'a' } "longer" => @list;
        }
    );
    is_dying( sub { &insert_after( 42, 4711, [qw(die bart die)] ); } );
    is_dying( sub { &insert_after( 42, 4711, "13" ); } );
    is_dying(
        sub {
            &insert_after( sub { }, 4711, "13" );
        }
    );
}

sub test_insert_after_string
{
    my @list = qw{This is a list};
    insert_after_string "a", "longer" => @list;
    is( join( ' ', @list ), "This is a longer list" );
    @list = ( undef, qw{This is a list} );
    insert_after_string "a", "longer", @list;
    shift @list;
    is( join( ' ', @list ), "This is a longer list" );
    @list = ( "This\0", "is\0", "a\0", "list\0" );
    insert_after_string "a\0", "longer\0", @list;
    is( join( ' ', @list ), "This\0 is\0 a\0 longer\0 list\0" );

    leak_free_ok(
        insert_after_string => sub {
            @list = qw{This is a list};
            insert_after_string "a", "longer", @list;
        }
    );
    is_dying( sub { &insert_after_string( 42, 4711, "13" ); } );
}

sub test_apply
{
    # Test the null case
    my $null_scalar = apply {};
    is( $null_scalar, undef, 'apply(null) returns undef' );

    my @null_list = apply {};
    is_deeply( \@null_list, [], 'apply(null) returns null list' );

    # Normal cases
    my @list = ( 0 .. 9 );
    my @list1 = apply { $_++ } @list;
    ok( is_deeply( \@list,  [ 0 .. 9 ] ) );
    ok( is_deeply( \@list1, [ 1 .. 10 ] ) );
    @list = ( " foo ", " bar ", "     ", "foobar" );
    @list1 = apply { s/^\s+|\s+$//g } @list;
    ok( is_deeply( \@list,  [ " foo ", " bar ", "     ", "foobar" ] ) );
    ok( is_deeply( \@list1, [ "foo",   "bar",   "",      "foobar" ] ) );
    my $item = apply { s/^\s+|\s+$//g } @list;
    is( $item, "foobar" );

    # RT 38630
  SCOPE:
    {
        # wrong results from apply() [XS]
        @list  = ( 1 .. 4 );
        @list1 = apply
        {
            grow_stack();
            $_ = 5;
        }
        @list;
        ok( is_deeply( \@list,  [ 1 .. 4 ] ) );
        ok( is_deeply( \@list1, [ (5) x 4 ] ) );
    }

    leak_free_ok(
        apply => sub {
            @list  = ( 1 .. 4 );
            @list1 = apply
            {
                grow_stack();
                $_ = 5;
            }
            @list;
        }
    );
    is_dying( sub { &apply( 42, 4711 ); } );
}

sub test_indexes
{
    my @x = indexes { $_ > 5 } ( 4 .. 9 );
    ok( is_deeply( \@x, [ 2 .. 5 ] ) );
    @x = indexes { $_ > 5 } ( 1 .. 4 );
    is_deeply( \@x, [], 'Got the null list' );

    my ( $lr, @s, @n, @o, @e );
    leak_free_ok(
        indexes => sub {
            $lr = 1;
            @s  = indexes { $_ > 5 } ( 4 .. 9 );
            @n  = indexes { $_ > 5 } ( 1 .. 5 );
            @o  = indexes { $_ & 1 } ( 10 .. 15 );
            @e  = indexes { !( $_ & 1 ) } ( 10 .. 15 );
        }
    );
    $lr and is_deeply( \@s, [ 2 .. 5 ], "indexes/leak: some" );
    $lr and is_deeply( \@n, [],         "indexes/leak: none" );
    $lr and is_deeply( \@o, [ 1, 3, 5 ], "indexes/leak: odd" );
    $lr and is_deeply( \@e, [ 0, 2, 4 ], "indexes/leak: even" );

    leak_free_ok(
        indexes => sub {
            @s = indexes { grow_stack; $_ > 5 } ( 4 .. 9 );
            @n = indexes { grow_stack; $_ > 5 } ( 1 .. 4 );
            @o = indexes { grow_stack; $_ & 1 } ( 10 .. 15 );
            @e = indexes { grow_stack; !( $_ & 1 ) } ( 10 .. 15 );
        }
    );

    $lr and is_deeply( \@s, [ 2 .. 5 ], "indexes/leak: some" );
    $lr and is_deeply( \@n, [],         "indexes/leak: none" );
    $lr and is_deeply( \@o, [ 1, 3, 5 ], "indexes/leak: odd" );
    $lr and is_deeply( \@e, [ 0, 2, 4 ], "indexes/leak: even" );

    if ($have_scalar_util)
    {
        my $ref = \( indexes( sub { 1 }, 123 ) );
        Scalar::Util::weaken($ref);
        is( $ref, undef, "weakened away" );
    }
    is_dying( sub { &indexes( 42, 4711 ); } );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before
{
    my @x = before { $_ % 5 == 0 } 1 .. 9;
    ok( is_deeply( \@x, [ 1, 2, 3, 4 ] ) );
    @x = before { /b/ } my @dummy = qw{ bar baz };
    is_deeply( \@x, [], 'Got the null list' );
    @x = before { /f/ } @dummy = qw{ bar baz foo };
    ok( is_deeply( \@x, [qw{ bar baz }] ) );

    leak_free_ok(
        before => sub {
            @x = before { /f/ } @dummy = qw{ bar baz foo };
        }
    );
    is_dying( sub { &before( 42, 4711 ); } );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before_incl
{
    my @x = before_incl { $_ % 5 == 0 } 1 .. 9;
    ok( is_deeply( \@x, [ 1, 2, 3, 4, 5 ] ) );
    @x = before_incl { /foo/ } my @dummy = qw{ bar baz };
    ok( is_deeply( \@x, [qw{ bar baz }] ) );
    @x = before_incl { /f/ } @dummy = qw{ bar baz foo };
    ok( is_deeply( \@x, [qw{ bar baz foo }] ) );

    leak_free_ok(
        before_incl => sub {
            @x = before_incl { /z/ } @dummy = qw{ bar baz foo };
        }
    );
    is_dying( sub { &before_incl( 42, 4711 ); } );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after
{
    my @x = after { $_ % 5 == 0 } 1 .. 9;
    ok( is_deeply( \@x, [ 6, 7, 8, 9 ] ) );
    @x = after { /foo/ } my @dummy = qw{ bar baz };
    is_deeply( \@x, [], 'Got the null list' );
    @x = after { /b/ } @dummy = qw{ bar baz foo };
    ok( is_deeply( \@x, [qw{ baz foo }] ) );

    leak_free_ok(
        after => sub {
            @x = after { /z/ } @dummy = qw{ bar baz foo };
        }
    );
    is_dying( sub { &after( 42, 4711 ); } );

    @x = ( 1, after { /foo/ } qw(abc def) );
    is_deeply(\@x, [ 1 ], "check XS implementation doesn't mess up stack");
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after_incl
{
    my @x = after_incl { $_ % 5 == 0 } 1 .. 9;
    ok( is_deeply( \@x, [ 5, 6, 7, 8, 9 ] ) );
    @x = after_incl { /foo/ } my @dummy = qw{ bar baz };
    is_deeply( \@x, [], 'Got the null list' );
    @x = after_incl { /b/ } @dummy = qw{ bar baz foo };
    ok( is_deeply( \@x, [qw{ bar baz foo }] ) );

    leak_free_ok(
        after_incl => sub {
            @x = after_incl { /z/ } @dummy = qw{ bar baz foo };
        }
    );
    is_dying( sub { &after_incl( 42, 4711 ); } );
}

sub test_firstval
{
    my $x = firstval { $_ > 5 } 4 .. 9;
    is( $x, 6 );
    $x = firstval { $_ > 5 } 1 .. 4;
    is( $x, undef );
    is_undef( firstval { $_ > 5 } );

    # Test aliases
    $x = first_value { $_ > 5 } 4 .. 9;
    is( $x, 6 );
    $x = first_value { $_ > 5 } 1 .. 4;
    is( $x, undef );

    leak_free_ok(
        firstval => sub {
            $x = firstval { $_ > 5 } 4 .. 9;
        }
    );
    is_dying( sub { &firstval( 42, 4711 ); } );
}

sub test_onlyval
{
    my @list = ( 1 .. 300 );
    is( 1,     onlyval { 1 == $_ } @list );
    is( 150,   onlyval { 150 == $_ } @list );
    is( 300,   onlyval { 300 == $_ } @list );
    is( undef, onlyval { 0 == $_ } @list );
    is( undef, onlyval { 1 <= $_ } @list );
    is( undef, onlyval { !( 127 & $_ ) } @list );

    # Test aliases
    is( 1,     only_value { 1 == $_ } @list );
    is( 150,   only_value { 150 == $_ } @list );
    is( 300,   only_value { 300 == $_ } @list );
    is( undef, only_value { 0 == $_ } @list );
    is( undef, only_value { 1 <= $_ } @list );
    is( undef, only_value { !( 127 & $_ ) } @list );

    leak_free_ok(
        onlyval => sub {
            my $ok  = onlyval { 150 <= $_ } @list;
            my $ok2 = onlyval { 150 <= $_ } 1 .. 300;
        }
    );
    is_dying( sub { &onlyval( 42, 4711 ); } );
}

sub test_lastval
{
    my $x = lastval { $_ > 5 } 4 .. 9;
    is( $x, 9 );
    $x = lastval { $_ > 5 } 1 .. 4;
    is( $x, undef );
    is_undef( lastval { $_ > 5 } );

    # Test aliases
    $x = last_value { $_ > 5 } 4 .. 9;
    is( $x, 9 );
    $x = last_value { $_ > 5 } 1 .. 4;
    is( $x, undef );

    leak_free_ok(
        lastval => sub {
            $x = lastval { $_ > 5 } 4 .. 9;
        }
    );
    is_dying( sub { &lastval( 42, 4711 ); } );
}

sub test_firstres
{
    my $x = firstres { 2 * ( $_ > 5 ) } 4 .. 9;
    is( $x, 2 );
    $x = firstres { $_ > 5 } 1 .. 4;
    is( $x, undef );

    # Test aliases
    $x = first_result { $_ > 5 } 4 .. 9;
    is( $x, 1 );
    $x = first_result { $_ > 5 } 1 .. 4;
    is( $x, undef );

    leak_free_ok(
        firstres => sub {
            $x = firstres { $_ > 5 } 4 .. 9;
        }
    );
    is_dying( sub { &firstres( 42, 4711 ); } );
}

sub test_lastres
{
    my $x = lastres { 2 * ( $_ > 5 ) } 4 .. 9;
    is( $x, 2 );
    $x = lastres { $_ > 5 } 1 .. 4;
    is( $x, undef );

    # Test aliases
    $x = last_result { $_ > 5 } 4 .. 9;
    is( $x, 1 );
    $x = last_result { $_ > 5 } 1 .. 4;
    is( $x, undef );

    leak_free_ok(
        lastres => sub {
            $x = lastres { $_ > 5 } 4 .. 9;
        }
    );
    is_dying( sub { &lastres( 42, 4711 ); } );
}

sub test_onlyres
{
    my @list = ( 1 .. 300 );
    is( "Hallelujah", onlyres { 150 == $_ and "Hallelujah" } @list );
    is( 1,            onlyres { 300 == $_ } @list );
    is( undef,        onlyres { 0 == $_ } @list );
    is( undef,        onlyres { 1 <= $_ } @list );
    is( undef,        onlyres { !( 127 & $_ ) } @list );

    # Test aliases
    is( 1,            only_result { 150 == $_ } @list );
    is( "Hallelujah", only_result { 300 == $_ and "Hallelujah" } @list );
    is( undef,        only_result { 0 == $_ } @list );
    is( undef,        only_result { 1 <= $_ } @list );
    is( undef,        only_result { !( 127 & $_ ) } @list );

    leak_free_ok(
        onlyres => sub {
            my $ok  = onlyres { 150 <= $_ } @list;
            my $ok2 = onlyres { 150 <= $_ } 1 .. 300;
        }
    );
    is_dying( sub { &onlyres( 42, 4711 ); } );
}

sub test_each_array
{
  SCOPE:
    {
        my @a  = ( 7, 3, 'a', undef, 'r' );
        my @b  = qw{ a 2 -1 x };
        my $it = each_array @a, @b;
        my ( @r, @idx );
        while ( my ( $a, $b ) = $it->() )
        {
            push @r, $a, $b;
            push @idx, $it->('index');
        }

        # Do I segfault? I shouldn't.
        $it->();

        ok( is_deeply( \@r, [ 7, 'a', 3, 2, 'a', -1, undef, 'x', 'r', undef ] ) );
        ok( is_deeply( \@idx, [ 0 .. 4 ] ) );

        # Testing two iterators on the same arrays in parallel
        @a = ( 1, 3, 5 );
        @b = ( 2, 4, 6 );
        my $i1 = each_array @a, @b;
        my $i2 = each_array @a, @b;
        @r = ();
        while ( my ( $a, $b ) = $i1->() and my ( $c, $d ) = $i2->() )
        {
            push @r, $a, $b, $c, $d;
        }
        ok( is_deeply( \@r, [ 1, 2, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6 ] ) );

        # Input arrays must not be modified
        ok( is_deeply( \@a, [ 1, 3, 5 ] ) );
        ok( is_deeply( \@b, [ 2, 4, 6 ] ) );

        # This used to give "semi-panic: attempt to dup freed string"
        # See: <news:1140827861.481475.111380@z34g2000cwc.googlegroups.com>
        my $ea = each_arrayref( [ 1 .. 26 ], [ 'A' .. 'Z' ] );
        ( @a, @b ) = ();
        while ( my ( $a, $b ) = $ea->() )
        {
            push @a, $a;
            push @b, $b;
        }
        ok( is_deeply( \@a, [ 1 .. 26 ] ) );
        ok( is_deeply( \@b, [ 'A' .. 'Z' ] ) );

        # And this even used to dump core
        my @nums = 1 .. 26;
        $ea = each_arrayref( \@nums, [ 'A' .. 'Z' ] );
        ( @a, @b ) = ();
        while ( my ( $a, $b ) = $ea->() )
        {
            push @a, $a;
            push @b, $b;
        }
        ok( is_deeply( \@a, [ 1 .. 26 ] ) );
        ok( is_deeply( \@a, \@nums ) );
        ok( is_deeply( \@b, [ 'A' .. 'Z' ] ) );
    }

  SCOPE:
    {
        my @a = ( 7, 3, 'a', undef, 'r' );
        my @b = qw/a 2 -1 x/;

        my $it = each_arrayref \@a, \@b;
        my ( @r, @idx );
        while ( my ( $a, $b ) = $it->() )
        {
            push @r, $a, $b;
            push @idx, $it->('index');
        }

        # Do I segfault? I shouldn't.
        $it->();

        ok( is_deeply( \@r, [ 7, 'a', 3, 2, 'a', -1, undef, 'x', 'r', undef ] ) );
        ok( is_deeply( \@idx, [ 0 .. 4 ] ) );

        # Testing two iterators on the same arrays in parallel
        @a = ( 1, 3, 5 );
        @b = ( 2, 4, 6 );
        my $i1 = each_array @a, @b;
        my $i2 = each_array @a, @b;
        @r = ();
        while ( my ( $a, $b ) = $i1->() and my ( $c, $d ) = $i2->() )
        {
            push @r, $a, $b, $c, $d;
        }
        ok( is_deeply( \@r, [ 1, 2, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6 ] ) );

        # Input arrays must not be modified
        ok( is_deeply( \@a, [ 1, 3, 5 ] ) );
        ok( is_deeply( \@b, [ 2, 4, 6 ] ) );
    }

    # Note that the leak_free_ok tests for each_array and each_arrayref
    # should not be run until either of them has been called at least once
    # in the current perl.  That's because calling them the first time
    # causes the runtime to allocate some memory used for the OO structures
    # that their implementation uses internally.
    leak_free_ok(
        each_array => sub {
            my @a  = (1);
            my $it = each_array @a;
            while ( my ($a) = $it->() )
            {
            }
        }
    );
    leak_free_ok(
        each_arrayref => sub {
            my @a  = (1);
            my $it = each_arrayref \@a;
            while ( my ($a) = $it->() )
            {
            }
        }
    );
    is_dying( sub { &each_array( 42, 4711 ); } );
    is_dying( sub { &each_arrayref( 42, 4711 ); } );
}

sub test_pairwise
{
    my @a = ( 1, 2, 3, 4, 5 );
    my @b = ( 2, 4, 6, 8, 10 );
    my @c = pairwise { $a + $b } @a, @b;
    is_deeply( \@c, [ 3, 6, 9, 12, 15 ], "pw1" );

    @c = pairwise { $a * $b } @a, @b;    # returns (2, 8, 18)
    is_deeply( \@c, [ 2, 8, 18, 32, 50 ], "pw2" );

    # Did we modify the input arrays?
    is_deeply( \@a, [ 1, 2, 3, 4, 5 ], "pw3" );
    is_deeply( \@b, [ 2, 4, 6, 8, 10 ], "pw4" );

    # $a and $b should be aliases: test
    @b = @a = ( 1, 2, 3 );
    @c = pairwise { $a++; $b *= 2 } @a, @b;
    is_deeply( \@a, [ 2, 3, 4 ], "pw5" );
    is_deeply( \@b, [ 2, 4, 6 ], "pw6" );
    is_deeply( \@c, [ 2, 4, 6 ], "pw7" );

    # sub returns more than two items
    @a = ( 1, 1, 2, 3, 5 );
    @b = ( 2, 3, 5, 7, 11 );
    @c = pairwise { ($a) x $b } @a, @b;
    is_deeply( \@c, [ (1) x 2, (1) x 3, (2) x 5, (3) x 7, (5) x 11 ], "pw8" );


    ( @a, @b ) = ();
    push @a, int rand(1000) for 0 .. rand(1000);
    push @b, int rand(1000) for 0 .. rand(1000);
  SCOPE:
    {
        local $SIG{__WARN__} = sub { };    # XXX
        my @res1 = pairwise { $a + $b } @a, @b;
	# Test this one more thoroughly: the XS code looks flakey
	# correctness of pairwise_perl proved by human auditing. :-)
	my $limit = $#a > $#b ? $#a : $#b;
        my @res2 = map { $a[$_] + $b[$_] } 0 .. $limit;
        is_deeply( \@res1, \@res2 );
    }

    @a = qw/a b c/;
    @b = qw/1 2 3/;
    @c = pairwise { ( $a, $b ) } @a, @b;
    is_deeply( \@c, [qw/a 1 b 2 c 3/], "pw map" );

  SKIP:
    {
        $ENV{PERL5OPT} and skip 'A defined PERL5OPT may inject extra deps crashing this test', 1;
        # Test that a die inside the code-reference will not be trapped
        eval {
            pairwise { die "I died\n" } @a, @b;
        };
        is( $@, "I died\n" );
    }

    leak_free_ok(
        pairwise => sub {
            @a = (1);
            @b = (2);
            @c = pairwise { $a + $b } @a, @b;
        }
    );
    @a = qw/a b c/;
    @b = qw/1 2 3/;

  SKIP:
    {
        List::MoreUtils::_XScompiled or skip "PurePerl will warn here ...", 1;
        my ( $a, $b, @t );
        eval {
            my @l1 = ( 1 .. 10 );
            @t = pairwise { $a + $b } @l1, @l1;
        };
        my $err = $@;
        like( $err, qr/Can't use lexical \$a or \$b in pairwise code block/, "pairwise die's on broken caller" );
    }

  SKIP:
    {
        List::MoreUtils::_XScompiled and skip "XS will die on purpose here ...", 1;
        my @warns = ();
        local $SIG{__WARN__} = sub { push @warns, @_ };
        my ( $a, $b, @t );
        my @l1 = ( 1 .. 10 );
        @t = pairwise { $a + $b } @l1, @l1;
        like( join( "", @warns[ 0, 1 ] ), qr/Use of uninitialized value.*? in addition/, "warning on broken caller" );
    }

    is_dying( sub { &pairwise( 42, \@a, \@b ); } );
  SKIP:
    {
        List::MoreUtils::_XScompiled or skip "PurePerl will not core here ...", 2;
        is_dying(
            sub {
                @c = &pairwise( sub { }, 1, \@b );
            }
        );
        is_dying(
            sub {
                @c = &pairwise( sub { }, \@a, 2 );
            }
        );
    }
}

sub test_natatime
{
    my @x = ( 'a' .. 'g' );
    my $it = natatime 3, @x;
    my @r;
    local $" = " ";
    while ( my @vals = $it->() )
    {
        push @r, "@vals";
    }
    is( is_deeply( \@r, [ 'a b c', 'd e f', 'g' ] ), 1, "natatime1" );

    my @a = ( 1 .. 1000 );
    $it = natatime 1, @a;
    @r = ();
    while ( my @vals = &$it )
    {
        push @r, @vals;
    }
    is( is_deeply( \@r, \@a ), 1, "natatime2" );

    leak_free_ok(
        natatime => sub {
            my @y = 1;
            my $it = natatime 2, @y;
            while ( my @vals = $it->() )
            {
                # do nothing
            }
        }
    );
}

sub test_zip
{
  SCOPE:
    {
        my @x = qw/a b c d/;
        my @y = qw/1 2 3 4/;
        my @z = zip @x, @y;
        ok( is_deeply( \@z, [ 'a', 1, 'b', 2, 'c', 3, 'd', 4 ] ) );
    }

  SCOPE:
    {
        my @a = ('x');
        my @b = ( '1', '2' );
        my @c = qw/zip zap zot/;
        my @z = zip @a, @b, @c;
        ok( is_deeply( \@z, [ 'x', 1, 'zip', undef, 2, 'zap', undef, undef, 'zot' ] ) );
    }

  SCOPE:
    {
        # Make array with holes
        my @a = ( 1 .. 10 );
        my @d;
        $#d = 9;
        my @z = zip @a, @d;
        ok(
            is_deeply(
                \@z, [ 1, undef, 2, undef, 3, undef, 4, undef, 5, undef, 6, undef, 7, undef, 8, undef, 9, undef, 10, undef, ]
            )
        );
    }

    leak_free_ok(
        zip => sub {
            my @x = qw/a b c d/;
            my @y = qw/1 2 3 4/;
            my @z = zip @x, @y;
        }
    );
    is_dying( sub { &zip( 1, 2 ); } );
}

sub test_mesh
{
  SCOPE:
    {
        my @x = qw/a b c d/;
        my @y = qw/1 2 3 4/;
        my @z = mesh @x, @y;
        ok( is_deeply( \@z, [ 'a', 1, 'b', 2, 'c', 3, 'd', 4 ] ) );
    }

  SCOPE:
    {
        my @a = ('x');
        my @b = ( '1', '2' );
        my @c = qw/zip zap zot/;
        my @z = mesh @a, @b, @c;
        ok( is_deeply( \@z, [ 'x', 1, 'zip', undef, 2, 'zap', undef, undef, 'zot' ] ) );
    }

    # Make array with holes
  SCOPE:
    {
        my @a = ( 1 .. 10 );
        my @d;
        $#d = 9;
        my @z = mesh @a, @d;
        ok(
            is_deeply(
                \@z, [ 1, undef, 2, undef, 3, undef, 4, undef, 5, undef, 6, undef, 7, undef, 8, undef, 9, undef, 10, undef, ]
            )
        );
    }

    leak_free_ok(
        mesh => sub {
            my @x = qw/a b c d/;
            my @y = qw/1 2 3 4/;
            my @z = mesh @x, @y;
        }
    );
    is_dying( sub { &mesh( 1, 2 ); } );
}

sub test_uniq
{
  SCOPE:
    {
        my @a = map { ( 1 .. 10 ) } 0 .. 1;
        my @u = uniq @a;
        is_deeply( \@u, [ 1 .. 10 ] );
        my $u = uniq @a;
        is( 10, $u );
    }

    # Test aliases
  SCOPE:
    {
        my @a = map { ( 1 .. 10 ) } 0 .. 1;
        my @u = distinct @a;
        is_deeply( \@u, [ 1 .. 10 ] );
        my $u = distinct @a;
        is( 10, $u );
    }

    # Test strings
  SCOPE:
    {
        my @a = map { ( "a" .. "z" ) } 0 .. 1;
        my @u = uniq @a;
        is_deeply( \@u, [ "a" .. "z" ] );
        my $u = uniq @a;
        is( 26, $u );
    }

    # Test mixing strings and numbers
  SCOPE:
    {
        my @a  = ( ( map { ( 1 .. 10 ) } 0 .. 1 ), ( map { ( "a" .. "z" ) } 0 .. 1 ) );
        my $fa = freeze( \@a );
        my @u  = uniq map { $_ } @a;
        my $fu = freeze( \@u );
        is_deeply( \@u, [ 1 .. 10, "a" .. "z" ] );
        is( $fa, freeze( \@a ) );
        is( $fu, freeze( [ 1 .. 10, "a" .. "z" ] ) );
        my $u = uniq @a;
        is( 10 + 26, $u );
    }

  SCOPE:
    {
        my @a;
        tie @a, "Tie::StdArray";
        @a = ( ( map { ( 1 .. 10 ) } 0 .. 1 ), ( map { ( "a" .. "z" ) } 0 .. 1 ) );
        my @u = uniq @a;
        is_deeply( \@u, [ 1 .. 10, "a" .. "z" ] );
        @a = ( ( map { ( 1 .. 10 ) } 0 .. 1 ), ( map { ( "a" .. "z" ) } 0 .. 1 ) );
        my $u = uniq @a;
        is( 10 + 26, $u );
    }

  SCOPE:
    {
        my @foo = ( 'a', 'b', '', undef, 'b', 'c', '' );
        my @ufoo = ( 'a', 'b', '', undef, 'c' );
        is_deeply( [ uniq @foo ], \@ufoo, 'undef is supported correctly' );
    }

    leak_free_ok(
        uniq => sub {
            my @a = map { ( 1 .. 1000 ) } 0 .. 1;
            my @u = uniq @a;
            uniq @a[ 1 .. 100 ];
        }
    );

    # This test (and the associated fix) are from Kevin Ryde; see RT#49796
    leak_free_ok(
        'uniq with exception in overloading stringify',
        sub {
            eval {
                my $obj = DieOnStringify->new;
                my @u = uniq $obj, $obj;
            };
            eval {
                my $obj = DieOnStringify->new;
                my $u = uniq $obj, $obj;
            };
        }
    );
}

sub test_singleton
{
  SCOPE:
    {
        my @s = ( 1001 .. 1200 );
        my @d = map { ( 1 .. 1000 ) } 0 .. 1;
        my @a = ( @d, @s );
        my @u = singleton @a;
        is_deeply( \@u, [@s] );
        my $u = singleton @a;
        is( 200, $u );
    }

    # Test strings
  SCOPE:
    {
        my @s = ( "AA" .. "ZZ" );
        my @d = map { ( "aa" .. "zz" ) } 0 .. 1;
        my @a = ( @d, @s );
        my @u = singleton @a;
        is_deeply( \@u, [@s] );
        my $u = singleton @a;
        is( scalar @s, $u );
    }

    # Test mixing strings and numbers
  SCOPE:
    {
        my @s  = ( 1001 .. 1200, "AA" .. "ZZ" );
        my $fs = freeze( \@s );
        my @d  = map { ( 1 .. 1000, "aa" .. "zz" ) } 0 .. 1;
        my @a  = ( @d, @s );
        my $fa = freeze( \@a );
        my @u  = singleton map { $_ } @a;
        my $fu = freeze( \@u );
        is_deeply( \@u, [@s] );
        is( $fs, freeze( \@s ) );
        is( $fa, freeze( \@a ) );
        is( $fu, $fs );
        my $u = singleton @a;
        is( scalar @s, $u );
    }

  SCOPE:
    {
        my @a;
        tie @a, "Tie::StdArray";
        my @s = ( 1001 .. 1200, "AA" .. "ZZ" );
        my @d = map { ( 1 .. 1000, "aa" .. "zz" ) } 0 .. 1;
        @a = ( @d, @s );
        my @u = singleton map { $_ } @a;
        is_deeply( \@u, [@s] );
        @a = ( @d, @s );
        my $u = singleton @a;
        is( scalar @s, $u );
    }

  SCOPE:
    {
        my @foo = ( 'a', 'b', '', undef, 'b', 'c', '' );
        my @sfoo = ( 'a', undef, 'c' );
        is_deeply( [ singleton @foo ], \@sfoo, 'one undef is supported correctly by singleton' );
        @foo = ( 'a', 'b', '', undef, 'b', 'c', undef );
        @sfoo = ( 'a', '', 'c' );
        is_deeply( [ singleton @foo ], \@sfoo, 'twice undef is supported correctly by singleton' );
        is( ( scalar singleton @foo ), scalar @sfoo, 'scalar twice undef is supported correctly by singleton' );
    }

    leak_free_ok(
        uniq => sub {
            my @s = ( 1001 .. 1200, "AA" .. "ZZ" );
            my @d = map { ( 1 .. 1000, "aa" .. "zz" ) } 0 .. 1;
            my @a = ( @d, @s );
            my @u = singleton @a;
            scalar singleton @a;
        }
    );

    # This test (and the associated fix) are from Kevin Ryde; see RT#49796
    leak_free_ok(
        'singleton with exception in overloading stringify',
        sub {
            eval {
                my $obj = DieOnStringify->new;
                my @u = singleton $obj, $obj;
            };
            eval {
                my $obj = DieOnStringify->new;
                my $u = singleton $obj, $obj;
            };
        }
    );
}

sub test_part
{
    my @list = 1 .. 12;
    my $i    = 0;
    my @part = part { $i++ % 3 } @list;
    ok( is_deeply( $part[0], [ 1, 4, 7, 10 ] ) );
    ok( is_deeply( $part[1], [ 2, 5, 8, 11 ] ) );
    ok( is_deeply( $part[2], [ 3, 6, 9, 12 ] ) );

    $list[2] = 0;
    is( $part[2][0], 3, 'Values are not aliases' );

    @list = 1 .. 12;
    @part = part { 3 } @list;
    is( $part[0], undef );
    is( $part[1], undef );
    is( $part[2], undef );
    ok( is_deeply( $part[3], [ 1 .. 12 ] ) );

    eval {
        @part = part { -1 } @list;
    };
    like( $@, qr/^Modification of non-creatable array value attempted, subscript -1/ );

    $i = 0;
    @part = part { $i++ == 0 ? 0 : -1 } @list;
    is_deeply( $part[0], [ 1 .. 12 ], "part with negative indices" );

  SKIP:
    {
        List::MoreUtils::_XScompiled and skip "Only PurePerl will warn here ...", 1;
        my @warns = ();
        local $SIG{__WARN__} = sub { push @warns, [@_] };
        @part = part { undef } @list;
        is_deeply( $part[0], [ 1 .. 12 ], "part with undef" );
        like( join( "\n", @{ $warns[0] } ), qr/Use of uninitialized value in array element.*line\s+\d+\.$/, "warning of undef" );
        is_deeply( \@warns, [ ( $warns[0] ) x 12 ], "amount of similar undef warnings" );
    }

    @part = part { 10000 } @list;
    ok( is_deeply( $part[10000], [@list] ) );
    is( $part[0],           undef );
    is( $part[ @part / 2 ], undef );
    is( $part[9999],        undef );

    # Changing the list in place used to destroy
    # its elements due to a wrong refcnt
    @list = 1 .. 10;
    @list = part { $_ } @list;
    foreach ( 1 .. 10 )
    {
        ok( is_deeply( $list[$_], [$_] ) );
    }

    leak_free_ok(
        part => sub {
            my @list = 1 .. 12;
            my $i    = 0;
            my @part = part { $i++ % 3 } @list;
        }
    );

    leak_free_ok(
        'part with stack-growing' => sub {
            # This test is from Kevin Ryde; see RT#38699
            my @part = part { grow_stack(); 1024 } 'one', 'two';
        }
    );
}

sub test_minmax
{
    my @list = reverse 0 .. 10000;
    my ( $min, $max ) = minmax @list;
    is( $min, 0 );
    is( $max, 10000 );

    # Even number of elements
    push @list, 10001;
    ( $min, $max ) = minmax @list;
    is( $min, 0 );
    is( $max, 10001 );
    $list[0] = 17;

    # Some floats
    @list = ( 0, -1.1, 3.14, 1 / 7, 10000, -10 / 3 );
    ( $min, $max ) = minmax @list;

    # Floating-point comparison cunningly avoided
    is( sprintf( "%.2f", $min ), "-3.33" );
    is( $max, 10000 );

    # Test with a single negative list value
    my $input = -1;
    ( $min, $max ) = minmax $input;
    is( $min, -1 );
    is( $max, -1 );

    # COW causes missing max when optimization for 1 argument is applied
    @list = grep {defined $_ } map { my ($min, $max) = minmax(sprintf("%.3g", rand)); ($min, $max) } (0..19);
    is( scalar @list, 40, "minmax swallows max on COW" );

    # Confirm output are independant copies of input
    $input = 1;
    is( $min, -1 );
    is( $max, -1 );
    $min = 2;
    is( $max, -1 );

    # prove overrun
    my $uvmax    = ~0;
    my $ivmax    = $uvmax >> 1;
    my $ivmin    = ( 0 - $ivmax ) - 1;
    my @low_ints = map { $ivmin + $_ } ( 0 .. 10 );
    ( $min, $max ) = minmax @low_ints;
    is( $min, $ivmin,      "minmax finds ivmin" );
    is( $max, $ivmin + 10, "minmax finds ivmin + 10" );

    my @high_ints = map { $ivmax - $_ } ( 0 .. 10 );
    ( $min, $max ) = minmax @high_ints;
    is( $min, $ivmax - 10, "minmax finds ivmax-10" );
    is( $max, $ivmax,      "minmax finds ivmax" );

    my @mixed_ints = map { ( $ivmin + $_, $ivmax - $_ ) } ( 0 .. 10 );
    ( $min, $max ) = minmax @mixed_ints;
    is( $min, $ivmin, "minmax finds ivmin" );
    is( $max, $ivmax, "minmax finds ivmax" );

    my @high_uints = map { $uvmax - $_ } ( 0 .. 10 );
    ( $min, $max ) = minmax @high_uints;
    is( $min, $uvmax - 10, "minmax finds uvmax-10" );
    is( $max, $uvmax,      "minmax finds uvmax" );

    my @mixed_nums = map { ( $ivmin + $_, $uvmax - $_ ) } ( 0 .. 10 );
    ( $min, $max ) = minmax @mixed_nums;
    is( $min, $ivmin, "minmax finds ivmin" );
    is( $max, $uvmax, "minmax finds uvmax" );

    leak_free_ok(
        minmax => sub {
            @list = ( 0, -1.1, 3.14, 1 / 7, 10000, -10 / 3 );
            ( $min, $max ) = minmax @list;
        }
    );
}

sub test_bsearch
{
    my @list = my @in = 1 .. 1000;
    for my $elem (@in)
    {
        ok( scalar bsearch { $_ - $elem } @list );
    }
    for my $elem (@in)
    {
        my ($e) = bsearch { $_ - $elem } @list;
        ok( $e == $elem );
    }
    my @out = ( -10 .. 0, 1001 .. 1011 );
    for my $elem (@out)
    {
        my $r = bsearch { $_ - $elem } @list;
        ok( !defined $r );
    }

    leak_free_ok(
        bsearch => sub {
            my $elem = int( rand(1000) ) + 1;
            scalar bsearch { $_ - $elem } @list;
        }
    );

    leak_free_ok(
        'bsearch with stack-growing' => sub {
            my $elem = int( rand(1000) );
            scalar bsearch { grow_stack(); $_ - $elem } @list;
        }
    );

    leak_free_ok(
        'bsearch with stack-growing and exception' => sub {
            my $elem = int( rand(1000) );
            eval {
                scalar bsearch { grow_stack(); $_ - $elem or die "Goal!"; $_ - $elem } @list;
            };
        }
    );
    is_dying( sub { &bsearch( 42, ( 1 .. 100 ) ); } );
}

sub test_bsearchidx
{
    my @list = my @in = 1 .. 1000;
    for my $i ( 0 .. $#in )
    {
        is( $i, bsearchidx { $_ - $in[$i] } @list );
    }
    my @out = ( -10 .. 0, 1001 .. 1011 );
    for my $elem (@out)
    {
        my $r = bsearchidx { $_ - $elem } @list;
        is( -1, $r );
    }

    leak_free_ok(
        bsearch => sub {
            my $elem = int( rand(1000) ) + 1;
            bsearchidx { $_ - $elem } @list;
        }
    );

    leak_free_ok(
        'bsearch with stack-growing' => sub {
            my $elem = int( rand(1000) );
            bsearchidx { grow_stack(); $_ - $elem } @list;
        }
    );

    leak_free_ok(
        'bsearch with stack-growing and exception' => sub {
            my $elem = int( rand(1000) );
            eval {
                bsearchidx { grow_stack(); $_ - $elem or die "Goal!"; $_ - $elem } @list;
            };
        }
    );
    is_dying( sub { &bsearchidx( 42, ( 1 .. 100 ) ); } );
}

sub test_any
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( any  { $_ == 5000 } @list );
    is_true( any  { $_ == 5000 } 1 .. 10000 );
    is_true( any  { defined } @list );
    is_false( any { not defined } @list );
    is_true( any  { not defined } undef );
    is_false( any {} );

    leak_free_ok(
        any => sub {
            my $ok  = any { $_ == 5000 } @list;
            my $ok2 = any { $_ == 5000 } 1 .. 10000;
        }
    );
    leak_free_ok(
        'any with a coderef that dies' => sub {
            # This test is from Kevin Ryde; see RT#48669
            eval {
                my $ok = any { die } 1;
            };
        }
    );
    is_dying( sub { &any( 42, 4711 ); } );
}

sub test_all
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( all  { defined } @list );
    is_true( all  { $_ > 0 } @list );
    is_false( all { $_ < 5000 } @list );
    is_true( all {} );

    leak_free_ok(
        all => sub {
            my $ok  = all { $_ == 5000 } @list;
            my $ok2 = all { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &all( 42, 4711 ); } );
}

sub test_none
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( none  { not defined } @list );
    is_true( none  { $_ > 10000 } @list );
    is_false( none { defined } @list );
    is_true( none {} );

    leak_free_ok(
        none => sub {
            my $ok  = none { $_ == 5000 } @list;
            my $ok2 = none { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &none( 42, 4711 ); } );
}

sub test_notall
{
    # Normal cases
    my @list = ( 1 .. 10000 );
    is_true( notall  { !defined } @list );
    is_true( notall  { $_ < 10000 } @list );
    is_false( notall { $_ <= 10000 } @list );
    is_false( notall {} );

    leak_free_ok(
        notall => sub {
            my $ok  = notall { $_ == 5000 } @list;
            my $ok2 = notall { $_ == 5000 } 1 .. 10000;
        }
    );
    is_dying( sub { &notall( 42, 4711 ); } );
}

sub test_one
{
    # Normal cases
    my @list = ( 1 .. 300 );
    is_true( one  { 1 == $_ } @list );
    is_true( one  { 150 == $_ } @list );
    is_true( one  { 300 == $_ } @list );
    is_false( one { 0 == $_ } @list );
    is_false( one { 1 <= $_ } @list );
    is_false( one { !( 127 & $_ ) } @list );

    leak_free_ok(
        one => sub {
            my $ok  = one { 150 <= $_ } @list;
            my $ok2 = one { 150 <= $_ } 1 .. 300;
        }
    );
    is_dying( sub { &one( 42, 4711 ); } );
}

sub test_sort_by
{
    my @list = map { [$_] } 1 .. 100;
    is_deeply( [ sort_by { $_->[0] } @list ], [ map { [$_] } sort { $a cmp $b } 1 .. 100 ] );
}

sub test_nsort_by
{
    my @list = map { [$_] } 1 .. 100;
    is_deeply( [ nsort_by { $_->[0] } @list ], [ map { [$_] } sort { $a <=> $b } 1 .. 100 ] );
}

1;
