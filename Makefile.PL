#!perl

use strict;
use warnings;

require 5.006;

BEGIN
{
    # to operate Capture::Tiny under perl 5.6
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

use inc::latest 'Capture::Tiny';
use inc::latest 'Config::AutoConf';

if ( inc::latest->can("write") )
{
    inc::latest->write("inc");
    for my $mod ( inc::latest->loaded_modules )
    {
        inc::latest->bundle_module( $mod, "inc" );
    }
}

use ExtUtils::MakeMaker;

use inc::Config::AutoConf::LMU ();

if ( -d "Sandbox" )
{
    eval "use Sandbox::Tumble ();";
    $@ and die $@;
    eval "use File::Path ();";
    File::Path->import;
    -d 't/xs'       and rmtree('t/xs');
    -d 't/pureperl' and rmtree('t/pureperl');
    Sandbox::Tumble->tumble(qw(t));
}

inc::Config::AutoConf::LMU->_set_argv(@ARGV);    # XXX hack because we cannot construct for global use

my $loadable_xs = inc::Config::AutoConf::LMU->check_produce_loadable_xs_build();

# Should we build the XS version?
my %RUN_DEPS = (
    'XSLoader'       => "0.22",
    'Exporter::Tiny' => '0.038',
);
my %BUNDLE_CONFIGURE_DEPS = (
    'inc::latest'      => '0.500',
    'Config::AutoConf' => '0.308',
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
                web    => 'https://rt.cpan.org/Dist/Display.html?Name=List-MoreUtils',
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
                    'JSON::PP'                            => 0,
                    'Test::WriteVariants'                 => '0.010',
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
            INC     => "-I."
          )
        : ()
    ),
    ( -d ".git" ? ( realclean => { FILES => "inc/latest* inc/inc_* t/pureperl t/xs" } ) : () ),
    depend => { '$(FIRST_MAKEFILE)' => '$(VERSION_FROM)' },
    test   => { TESTS               => join( ' ', 't/*.t', 't/pureperl/*.t', ( $loadable_xs ? 't/xs/*.t' : () ), 'xt/*.t' ) },
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
