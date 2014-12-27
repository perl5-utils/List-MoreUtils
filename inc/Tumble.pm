package Tumble;

use strict;
use warnings;

use Cwd qw();
use File::Find;
use File::Path;
use File::Spec qw();
use File::Basename;
use Data::Dumper 0.002;
use Test::WriteVariants 0.005;

use Config::AutoConf::LMU ();
use FindBin qw();

$| = 1;

sub tumble
{
    my ( $class ) = @_;

    my $plug_dir = Cwd::abs_path( File::Spec->catdir( $FindBin::RealBin, "t", "lib" ) );
    my $test_writer = Test::WriteVariants->new();

    $test_writer->write_test_variants(
	input_tests => $test_writer->find_input_test_modules(
	    search_path => [ 'LMU::Test' ],
	    search_dirs => [ $plug_dir ],
	    test_prefix => '',
	),
	variant_providers => [
	    "LMU::TestVariants",
	],
	output_dir => "gt",
    );
}

package Tumble::WriteTestVariants;

use base "Test::WriteVariants";

use Carp qw/croak/;
use File::Path qw/mkpath/;
use File::Basename qw/dirname/;

sub write_test_file
{
    my ( $self, $path, $context, $input_tests, $target_dir ) = @_;

    my $base_dir_path = File::Spec->catdir( $target_dir, @$path );

    # note that $testname can include a subdirectory path
    for my $testname ( sort keys %$input_tests )
    {
        my $testinfo = $input_tests->{$testname};

        $testname .= ".t" unless $testname =~ m/\.t$/;
        my $full_path = File::Spec->catfile( $base_dir_path, $testname );
        croak "$full_path already exists" if -e $full_path;
        warn "Writing $full_path\n";

        my $test_script = $self->get_test_file_body( $context, $testinfo );

        my $full_dir_path = dirname($full_path);
        mkpath( $full_dir_path, 0 ) unless -d $full_dir_path;

        open my $fh, ">", $full_path
	  or croak "Can't write $full_path: $!";
        print $fh $test_script;
        close $fh
	  or croak "Error writing to $full_path: $!";
    }

    return;
}

my $body_tpl = <<'EOB';
#!@PERL@

use strict;
@PRE@
@REQUIRE@

@CODE@

@POST@
EOB

my $tc_code_tpc = <<'EOTC';
@LIB@
require @TESTCASE@;
@TESTCASE@->run_tests;
EOTC

sub get_test_file_body
{
    my ( $self, $context, $testinfo ) = @_;

    my %vars = (
                 PERL    => $^X,
                 PRE     => $context->pre_code,
                 POST    => $context->post_code,
                 REQUIRE => ""
               );

    $testinfo->{require}
      and $vars{REQUIRE} = join( "\n", map { "require '$_';" } @{ $testinfo->{require} } );

    if ( $testinfo->{module} )
    {
        my %cv = (
                   TESTCASE => $testinfo->{module},
                   LIB      => ""
                 );
        $testinfo->{lib} and $cv{LIB} = "use lib '$testinfo->{lib}';\n";
        $vars{CODE} = $self->process_template( $tc_code_tpc, \%cv );
    }
    elsif ( $testinfo->{code} )
    {
        $vars{CODE} = $testinfo->{code};
    }

    return $self->process_template( $body_tpl, \%vars );
}

sub process_template
{
    my ( $self, $tpl, $vars ) = @_;
    my $varkeys = join( "|", keys %{$vars} );
    $tpl =~ s/@($varkeys)[@]/$vars->{$1}/ge;
    $tpl =~ s/\n{2,}/\n\n/g;    # simulate [%- .. -%]
    $tpl =~ s/\n+$/\n/g;
    return $tpl;
}

package LMU::TestVariants::CanXS;

use strict;
use warnings;

sub provider {
    my ($self, $path, $context, $tests, $variants) = @_;
    my $mod_ctx = $context->new_module_use( lib => [ File::Spec->catdir(qw(t lib)) ] );

    if(Config::AutoConf::LMU->check_produce_xs_build)
    {
	$variants->{pureperl} = $context->new( $context->new_env_var( LIST_MOREUTILS_PP => 1,), $mod_ctx );
	$variants->{xs} = $context->new( $context->new_env_var( LIST_MOREUTILS_PP => 0,), $mod_ctx );
    }
    else
    {
	$variants->{Default} = $context->new( $mod_ctx );
    }
}

1;
