package Tumble;

use strict;
use warnings;

use autodie;
use Cwd qw();
use File::Find;
use File::Path;
use File::Spec qw();
use File::Basename;
use Data::Dumper;
#use Package::Stash qw();
#use Module::Runtime;
use Module::Pluggable::Object;

use Config::AutoConf::LMU ();

use FindBin qw();

use Context;
use WriteTestVariants;

$| = 1;
my $output_dir = "out";

sub tumble
{
    my $plug_dir = Cwd::abs_path( File::Spec->catdir( $FindBin::RealBin, "t", "lib" ) );

    my $test_writer = WriteTestVariants->new( test_case_default_namespace => "LMU::Test",
                                              test_case_search_dirs       => [$plug_dir], );

    $test_writer->write_test_variants( $output_dir, [ \&lmu_settings_provider, ], );
}

sub lmu_settings_provider
{
    my %settings = (
                     Default => Context->new,
                   );
    Config::AutoConf::LMU->with_xs
      and %settings = (
                        pureperl => Context->new_env_var( LIST_MOREUTILS_PP => 1 ),
                        xs       => Context->new_env_var( LIST_MOREUTILS_PP => 0 ),
                      );

    return %settings;
}

1;
