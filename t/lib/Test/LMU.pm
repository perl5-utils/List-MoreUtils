package t::lib::Test::LMU;

use 5.008001;

use strict;
use warnings;

######################################################################
# Support Functions

sub is_true {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    die "Expected 1 param" unless @_ == 1;
    ok( $_[0], "is_true ()" );
}

sub is_false {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    die "Expected 1 param" unless @_ == 1;
    ok( !$_[0], "is_false()" );
}

my @bigary = ( 1 ) x 500;

sub func { }

sub grow_stack {
    func(@bigary);
}

sub leak_free_ok {
    my $name = shift;
    my $code = shift;
    SKIP: {
        skip 'Test::LeakTrace not installed', 1
            unless eval { require Test::LeakTrace; 1 };
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
