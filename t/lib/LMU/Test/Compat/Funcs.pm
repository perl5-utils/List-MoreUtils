package LMU::Test::Compat::Funcs;

use strict;
BEGIN {
	$|  = 1;
}

use Test::More;
use Test::LMU;
require List::MoreUtils;

my %groups = (List::MoreUtils->_export_tags, List::MoreUtils->_export_alias_names);
my %funcs = map {$_ => 1} map { @{$_} } values %groups;

sub run_tests
{
    my $class = shift;

    $class->test_any();
    $class->test_all();
    $class->test_none();
    $class->test_notall();

    $class->test_true();
    $class->test_false();
    $class->test_firstidx();
    $class->test_lastidx();
    $class->test_insert_after();
    $class->test_insert_after_string();
    $class->test_apply();
    $class->test_indexes();
    $class->test_before();
    $class->test_before_incl();
    $class->test_after();
    $class->test_after_incl();
    $class->test_firstval();
    $class->test_lastval();
    $class->test_each_array();
    $class->test_pairwise();
    $class->test_natatime();
    $class->test_zip();
    $class->test_mesh();
    $class->test_uniq();
    $class->test_part();
    $class->test_minmax();
    $class->test_bsearch();

    $class->test_sort_by();
    $class->test_nsort_by();

    done_testing();
}

sub test_any {
    my @list = ( 1 .. 10000 );
    is_true( List::MoreUtils::any( sub { $_ == 5000 }, @list ) );
}

sub test_all {
    my @list = ( 1 .. 10000 );
    is_true( List::MoreUtils::all( sub { defined }, @list ) );
}

sub test_none {
    my @list = ( 1 .. 10000 );
    is_true( List::MoreUtils::none( sub { not defined }, @list ) );
}

sub test_notall {
    my @list = ( 1 .. 10000 );
    is_true( List::MoreUtils::notall( sub { ! defined }, @list ) );
}

sub test_true {
    my @list = ( 1 .. 10000 );
    is( 1, List::MoreUtils::true( sub { $_ == 5000 }, @list ) );
}

sub test_false {
    my @list = ( 1 .. 10000 );
    is( 1, List::MoreUtils::false( sub { $_ > 1 }, @list ) );
}

sub test_firstidx {
    my @list = ( 1 .. 10000 );
    is( 4999, List::MoreUtils::firstidx( sub { $_ >= 5000 }, @list ) );
}

sub test_lastidx {
    my @list = ( 1 .. 10000 );
    is( 9999, List::MoreUtils::lastidx( sub { $_ >= 5000 }, @list ) );
}

sub test_insert_after {
    my @list = qw{This is a list};
    List::MoreUtils::insert_after( sub { $_ eq "a" }, "longer", \@list );
    is( join(' ', @list), "This is a longer list" );
}

sub test_insert_after_string {
    my @list = qw{This is a list};
    List::MoreUtils::insert_after_string( "a", "longer", \@list );
    is( join(' ', @list), "This is a longer list" );
}

sub test_apply {
    my @list  = ( 0 .. 9 );
    my @list1 = List::MoreUtils::apply( sub { $_++ }, @list);
    is_deeply( \@list,  [ 0 .. 9  ] );
}

sub test_indexes {
    my @x = List::MoreUtils::indexes( sub { $_ > 5 }, ( 4 .. 9 ));
    is_deeply( \@x, [ 2..5 ] );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before {
    my @x = List::MoreUtils::before( sub { $_ % 5 == 0 }, (1 .. 9));
    is_deeply( \@x, [ 1, 2, 3, 4 ] );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_before_incl {
    my @x = List::MoreUtils::before_incl( sub { $_ % 5 == 0 }, (1 .. 9));
    is_deeply( \@x, [ 1, 2, 3, 4, 5 ] );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after {
    my @x = List::MoreUtils::after( sub { $_ % 5 == 0 }, (1 .. 9));
    is_deeply( \@x, [ 6, 7, 8, 9 ] );
}

# In the following, the @dummy variable is needed to circumvent
# a parser glitch in the 5.6.x series.
sub test_after_incl {
    my @x = List::MoreUtils::after_incl( sub { $_ % 5 == 0 }, (1 .. 9));
    is_deeply( \@x, [ 5, 6, 7, 8, 9 ] );
}

sub test_firstval {
    my $x = List::MoreUtils::firstval( sub { $_ > 5 }, (4 .. 9));
    is( $x, 6 );
}

sub test_lastval {
    my $x = List::MoreUtils::lastval( sub { $_ > 5 }, (4..9));
    is( $x, 9 );
}

sub test_each_array {
    SCOPE: {
        my @a  = ( 7, 3, 'a', undef, 'r' );
        my @b  = qw{ a 2 -1 x };
        my $it = List::MoreUtils::each_array(\@a, \@b);
        my (@r, @idx);
        while ( my ($a, $b) = $it->() ) {
            push @r, $a, $b;
            push @idx, $it->('index');
        }

        # Do I segfault? I shouldn't. 
        $it->();

        is_deeply( \@r, [ 7, 'a', 3, 2, 'a', -1, undef, 'x', 'r', undef ] );
        is_deeply( \@idx, [ 0 .. 4 ] );
    }
}

sub test_pairwise {
    my @a = (1, 2, 3, 4, 5);
    my @b = (2, 4, 6, 8, 10);
    my @c = List::MoreUtils::pairwise( sub { $a + $b }, \@a, \@b );
    is_deeply( \@c, [ 3, 6, 9, 12, 15 ], "pw1" );
}

sub test_natatime {
    my @x = ( 'a'..'g' );
    my $it = List::MoreUtils::natatime( 3, @x );
    my @r;
    local $" = " ";
    while ( my @vals = $it->() ) {
        push @r, "@vals";
    }
    is_deeply( \@r, [ 'a b c', 'd e f', 'g' ], "natatime1" );
}

sub test_zip {
    my @x = qw/a b c d/;
    my @y = qw/1 2 3 4/;
    my @z = List::MoreUtils::zip(\@x, \@y);
    is_deeply(\@z, ['a', 1, 'b', 2, 'c', 3, 'd', 4]);
}

sub test_mesh {
    my @x = qw/a b c d/;
    my @y = qw/1 2 3 4/;
    my @z = List::MoreUtils::mesh(\@x, \@y);
    is_deeply( \@z, [ 'a', 1, 'b', 2, 'c', 3, 'd', 4 ] );
}

sub test_uniq {
    my @a = map { ( 1 .. 1000 ) } 0 .. 1;
    my @u = List::MoreUtils::uniq(@a);
    ok( is_deeply( \@u, [ 1 .. 1000 ] ) );
    my $u = List::MoreUtils::uniq(@a);
    is( 1000, $u );
}

sub test_part {
    my @list = 1 .. 12;
    my $i    = 0;
    my @part = List::MoreUtils::part( sub { $i++ % 3 }, @list );
    is_deeply($part[0], [ 1, 4, 7, 10 ]);
    is_deeply($part[1], [ 2, 5, 8, 11 ]);
    is_deeply($part[2], [ 3, 6, 9, 12 ]);
}

sub test_minmax {
    my @list = reverse 0 .. 10000;
    my ($min, $max) = List::MoreUtils::minmax(@list);
    is( $min, 0 );
    is( $max, 10000 );
}

sub test_bsearch {
    my @list = my @in = 1 .. 1000;
    for my $elem (@in) {
        ok(scalar List::MoreUtils::bsearch( sub { $_ - $elem }, @list));
    }
}

sub test_sort_by {
    my @list = map { [$_] } 1 .. 100;
    is_deeply([List::MoreUtils::sort_by( sub { $_->[0] },@list)], [map { [$_] } sort { $a cmp $b } 1..100]);
}

sub test_nsort_by {
    my @list = map { [$_] } 1 .. 100;
    is_deeply([List::MoreUtils::nsort_by( sub { $_->[0] },@list)], [map { [$_] } sort { $a <=> $b } 1..100]);
}

1;
