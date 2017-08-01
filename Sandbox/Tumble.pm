package Sandbox::Tumble;

use strict;
use warnings;

use Cwd qw();
use File::Spec qw();
use Test::WriteVariants 0.013;

use FindBin qw();

$| = 1;

sub tumble
{
    my ( $class, $output_dir ) = @_;

    my $template_dir = Cwd::abs_path( File::Spec->catdir( $FindBin::RealBin, "t", "inline" ) );
    my $test_writer = Test::WriteVariants->new();
    $test_writer->allow_dir_overwrite(1);
    $test_writer->allow_file_overwrite(1);

    $test_writer->write_test_variants(
        input_tests => $test_writer->find_input_inline_tests(
            search_patterns => ["*.pm"],,
            search_dirs => [$template_dir],
        ),
        variant_providers => [ "LMU::TestVariants", ],
        output_dir        => $output_dir,
    );
}

package LMU::TestVariants::Dist;

use strict;
use warnings;

sub provider
{
    my ( $self, $path, $context, $tests, $variants ) = @_;
    my $lib_ctx = $context->new_module_use( lib => [ File::Spec->catdir(qw(t lib)) ] );
    my $lmu_ctx = $context->new_module_use( 'List::MoreUtils' => [':all'] );
    my $strict = $context->new_module_use( strict => [qw(subs vars refs)] );
    my $warnings = $context->new_module_use( warnings => ['all'] );

    # statically generate both at dist authoring stage and decide about tests to run at configure stage
    $variants->{pureperl} = $context->new(
	$lmu_ctx,
        $lib_ctx,
        $context->new_env_var(
            LIST_MOREUTILS_PP => 1,
        ),
        $warnings,
        $strict,
    );
    $variants->{xs} = $context->new(
        $lib_ctx,
	$lmu_ctx,
        $context->new_env_var(
            LIST_MOREUTILS_PP => 0,
        ),
        $warnings,
        $strict,
    );
}

1;
