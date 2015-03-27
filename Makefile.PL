#!perl

use strict;
use warnings;

require 5.006;

use File::Basename qw(dirname);
use File::Copy qw(copy move);
use File::Spec ();

BEGIN
{
    use inc::latest 'JSON::PP';

    eval "use Storable qw();";
    $@ and eval <<'EODC';
$INC{'Storable.pm'} = 'faked';
package Storable;
use base "Exporter";
use JSON::PP qw();
our @EXPORT = qw(dclone);
sub dclone {
    my $json = JSON::PP->new();
    $json->decode($json->encode($_[0]));
}
1;
EODC

    eval "use Scalar::Util qw();";
    $@ and eval <<'EOSU';
$INC{'Scalar/Util.pm'} = 'faked';
package Scalar::Util;
use base "Exporter";
# from PP part of Params::Util
our @EXPORT = qw(reftype blessed looks_like_number);
sub reftype { ref $_[0] }
my %types = (
    CODE   => 1,
    GLOB   => 1,
    REF    => 1,
    SCALAR => 1,
    HASH   => 1,
    ARRAY  => 1
);
sub blessed {
    my $t = ref $_[0];
    defined $t or return;
    defined $types{$t} or return;
    $t;
}
# from PP part of Params::Util
sub looks_like_number {
    local $_ = shift;

    # checks from perlfaq4
    return 0 if !defined($_);
    if (ref($_)) {
        return overload::Overloaded($_) ? defined(0 + $_) : 0;
    }
    return 1 if (/^[+-]?[0-9]+$/); # is a +/- integer
    return 1 if (/^([+-]?)(?=[0-9]|\.[0-9])[0-9]*(\.[0-9]*)?([Ee]([+-]?[0-9]+))?$/); # a C float
    return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i) or ($] >= 5.006001 and /^Inf$/i);

    0;
}
EOSU
}

use inc::latest 'Data::Tumbler';
use inc::latest 'Module::Pluggable';
use inc::latest 'Test::WriteVariants';
use inc::latest 'Capture::Tiny';
use inc::latest 'Config::AutoConf';

if ( inc::latest->can("write") )
{
    inc::latest->write("inc");
    for my $mod ( inc::latest->loaded_modules )
    {
        inc::latest->bundle_module( $mod, "inc" );
    }
    my $src = $INC{"JSON/PP.pm"};
    $src = dirname($src);
    $src = File::Spec->catfile( $src, qw(backportPP Compat5006.pm) );
    -f $src and copy( $src, "inc/inc_JSON-PP/JSON/PP/" );
}

use lib 'inc';
use ExtUtils::MakeMaker;
use File::Path;

use Config::AutoConf::LMU ();
use Tumble                ();

Config::AutoConf::LMU->_set_argv(@ARGV);    # XXX hack because we cannot construct for global use

my $loadable_xs = Config::AutoConf::LMU->check_produce_loadable_xs_build();

-d "gt" and rmtree("gt");
Tumble->tumble("gt");

# Should we build the XS version?
my %RUN_DEPS = (
    'XSLoader'       => 0,
    'Exporter::Tiny' => '0.038',
);
my %BUNDLE_CONFIGURE_DEPS = (
    'inc::latest'         => '0.500',
    'JSON::PP'            => 0,
    'Test::WriteVariants' => '0.010',
    'Config::AutoConf'    => '0.308',
);
my %CONFIGURE_DEPS = (
    'Carp'                => 0,
    'ExtUtils::MakeMaker' => 0,
    'File::Basename'      => 0,
    'File::Copy'          => 0,
    'File::Path'          => 0,
    'File::Spec'          => 0,
    'IPC::Cmd'            => 0,
    'base'                => 0,
);
my %BUILD_DEPS = ();

my %TEST_DEPS = (
    'Test::More' => 0.96,
);
my @XS_FILES = qw(MoreUtils.xs);

WriteMakefile1(
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            homepage   => 'https://metacpan.org/release/List-MoreUtils',
            repository => {
                url  => 'https://github.com/perl5-utils/List-MoreUtils.git',
                web  => 'https://github.com/perl5-utils/List-MoreUtils',
                type => 'git',
            },
            bugtracker => {
                web    => 'http://rt.cpan.org/Public/Dist/Display.html?Name=List-MoreUtils',
                mailto => 'bug-List-MoreUtils@rt.cpan.org',
            },
            license => 'http://dev.perl.org/licenses/',
        },
        prereqs => {
            develop => {
                requires => {
                    'Test::CPAN::Changes'                 => 0,
                    'Test::CheckManifest'                 => 0,
                    'Module::CPANTS::Analyse'             => '0.96',
                    'Test::Kwalitee'                      => 0,
                    'Test::Pod'                           => 0,
                    'Test::Pod::Coverage'                 => 0,
                    'Test::Pod::Spelling::CommonMistakes' => 0,
                    'Test::Spelling'                      => 0,
                    %BUNDLE_CONFIGURE_DEPS,
                },
            },
            configure => {
                requires   => {%CONFIGURE_DEPS},
                recommends => {%BUNDLE_CONFIGURE_DEPS},
            },
            build => { requires => {%BUILD_DEPS} },
            test  => {
                requires   => {%TEST_DEPS},
                recommends => { 'Test::LeakTrace' => 0 }
            },
            runtime => {
                requires => { %RUN_DEPS, },
            },
        },
    },
    NAME         => 'List::MoreUtils',
    ABSTRACT     => 'Provide the stuff missing in List::Util',
    VERSION_FROM => 'lib/List/MoreUtils.pm',
    AUTHOR       => [
        'Tassilo von Parseval <tassilo.von.parseval@rwth-aachen.de>',
        'Adam Kennedy <adamk@cpan.org>',
        'Jens Rehsack <rehsack@cpan.org>'
    ],
    LICENSE            => 'perl',
    CONFIGURE_REQUIRES => \%CONFIGURE_DEPS,
    PREREQ_PM          => \%RUN_DEPS,
    BUILD_REQUIRES     => \%BUILD_DEPS,
    TEST_REQUIRES      => \%TEST_DEPS,
    (
        $loadable_xs
        ? (
            XS => { map { ( my $tgt = $_ ) =~ s/\.xs$/\.c/; $_ => $tgt; } @XS_FILES },
            MAGICXS => 1,
            #OBJECT => [ map { $_ =~ s/\.xs/\.o/; $_ } @XS_FILES ],
            #OBJECT => join(" ", map { $_ =~ s/\.xs/\.o/; $_ } @XS_FILES ),
            INC => "-I."
          )
        : ()
    ),
    clean  => { FILES               => "inc/latest* inc/inc_* gt" },
    depend => { '$(FIRST_MAKEFILE)' => '$(VERSION_FROM)' },
    test   => { TESTS               => 'xt/*.t gt/*/*.t gt/*/*/*.t' },
    # Otherwise 'cxinc' isn't defined
    ( $] < 5.012 ? ( DEFINE => '-DPERL_EXT' ) : (), ),
);

sub WriteMakefile1
{    # originally written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params       = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if ( exists( $params{EXTRA_META} ) );
    die "License not specified"    if ( !exists( $params{LICENSE} ) );
    $params{TEST_REQUIRES}
      and $eumm_version < 6.6303
      and $params{BUILD_REQUIRES} = { %{ $params{BUILD_REQUIRES} || {} }, %{ delete $params{TEST_REQUIRES} } };
    #EUMM 6.5502 has problems with BUILD_REQUIRES
    $params{BUILD_REQUIRES}
      and $eumm_version < 6.5503
      and $params{PREREQ_PM} = { %{ $params{PREREQ_PM} || {} }, %{ delete $params{BUILD_REQUIRES} } };
    ref $params{AUTHOR}
      and "ARRAY" eq ref $params{AUTHOR}
      and $eumm_version < 6.5702
      and $params{AUTHOR} = join( ", ", @{ $params{AUTHOR} } );
    delete $params{CONFIGURE_REQUIRES}    if ( $eumm_version < 6.52 );
    delete $params{MIN_PERL_VERSION}      if ( $eumm_version < 6.48 );
    delete $params{META_MERGE}            if ( $eumm_version < 6.46 );
    delete $params{META_ADD}{prereqs}     if ( $eumm_version < 6.58 );
    delete $params{META_ADD}{'meta-spec'} if ( $eumm_version < 6.58 );
    delete $params{META_ADD}              if ( $eumm_version < 6.46 );
    delete $params{LICENSE}               if ( $eumm_version < 6.31 );
    delete $params{AUTHOR}                if ( $] < 5.005 );
    delete $params{ABSTRACT_FROM}         if ( $] < 5.005 );
    delete $params{BINARY_LOCATION}       if ( $] < 5.005 );

    # more or less taken from Moose' Makefile.PL
    if ( $params{CONFLICTS} )
    {
        my $ok = CheckConflicts(%params);
        exit(0) if ( $params{PREREQ_FATAL} and not $ok );
        my $cpan_smoker = grep { $_ =~ m/(?:CR_SMOKER|CPAN_REPORTER|AUTOMATED_TESTING)/ } keys %ENV;
        unless ( $cpan_smoker || $ENV{PERL_MM_USE_DEFAULT} )
        {
            sleep 4 unless ($ok);
        }
        delete $params{CONFLICTS};
    }

    WriteMakefile(%params);
}
