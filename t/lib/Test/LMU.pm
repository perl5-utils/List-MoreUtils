package Test::LMU;

use strict;

require Exporter;
use Test::More import => ['!pass'];
use Carp qw/croak/;

use base qw(Test::Builder::Module Exporter);

our @EXPORT    = qw(is_true is_false is_defined is_undef is_dying grow_stack leak_free_ok);
our @EXPORT_OK = qw(is_true is_false is_defined is_undef is_dying grow_stack leak_free_ok);

my $CLASS = __PACKAGE__;

######################################################################
# Support Functions

sub is_true
{
    @_ == 1 or croak "Expected 1 param";
    my $tb = $CLASS->builder();
    $tb->ok( $_[0], "is_true ()" );
}

sub is_false
{
    @_ == 1 or croak "Expected 1 param";
    my $tb = $CLASS->builder();
    $tb->ok( !$_[0], "is_false()" );
}

sub is_defined
{
    @_ < 1 or croak "Expected 0..1 param";
    my $tb = $CLASS->builder();
    $tb->ok( defined( $_[0] ), "is_defined ()" );
}

sub is_undef
{
    @_ <= 1 or croak "Expected 0..1 param";
    my $tb = $CLASS->builder();
    $tb->ok( !defined( $_[0] ), "is_undef()" );
}

sub is_dying
{
    @_ == 1 or croak "Expected 1 param";
    my $tb = $CLASS->builder();
    eval { $_[0]->(); };
    $tb->ok( $@, "is_dying()" );
}

my @bigary = (1) x 500;

sub func { }

sub grow_stack
{
    func(@bigary);
}

my $have_test_leak_trace = eval { require Test::LeakTrace; 1 };

sub leak_free_ok
{
    my $name = shift;
    my $code = shift;
  SKIP:
    {
        skip 'Test::LeakTrace not installed', 1 unless $have_test_leak_trace;
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        &Test::LeakTrace::no_leaks_ok( $code, "No memory leaks in $name" );
    }
}

{

    package DieOnStringify;
    use overload '""' => \&stringify;
    sub new { bless {}, shift }
    sub stringify { die 'DieOnStringify exception' }
}

1;
