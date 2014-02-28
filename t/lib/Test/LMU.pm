package Test::LMU;

use 5.008001;

use strict;

require Exporter;
use Test::More import => [ '!pass' ];

use parent qw(Test::Builder::Module Exporter);

our @EXPORT = qw(is_true is_false is_defined is_undef grow_stack leak_free_ok);
our @EXPORT_OK = qw(is_true is_false is_defined is_undef grow_stack leak_free_ok);

my $CLASS = __PACKAGE__;

######################################################################
# Support Functions

sub is_true {
    my $tb = $CLASS->builder();
    die "Expected 1 param" unless @_ == 1;
    $tb->ok( $_[0], "is_true ()" );
}

sub is_false {
    my $tb = $CLASS->builder();
    die "Expected 1 param" unless @_ == 1;
    $tb->ok( !$_[0], "is_false()" );
}

sub is_defined {
    my $tb = $CLASS->builder();
    $tb->ok( defined($_[0]), "is_defined ()" );
}

sub is_undef {
    my $tb = $CLASS->builder();
    $tb->ok( !defined($_[0]), "is_undef()" );
}

my @bigary = ( 1 ) x 500;

sub func { }

sub grow_stack {
    func(@bigary);
}

my $have_test_leak_trace = eval { require Test::LeakTrace; 1 };

sub leak_free_ok {
    my $name = shift;
    my $code = shift;
    SKIP: {
        skip 'Test::LeakTrace not installed', 1 unless $have_test_leak_trace;
	local $Test::Builder::Level = $Test::Builder::Level + 1;
        &Test::LeakTrace::no_leaks_ok($code, "No memory leaks in $name");
    }
}

{
    package DieOnStringify;
    use overload '""' => \&stringify;
    sub new { bless {}, shift }
    sub stringify { die 'DieOnStringify exception' }
}

1;
