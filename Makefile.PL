#!perl

use strict;
use warnings;

require 5.008001;

use ExtUtils::MakeMaker;
use lib 'inc';
use Config::AutoConf::LMU ();
use Tumble;

Config::AutoConf::LMU->_set_argv(@ARGV);    # XXX hack because we cannot construct for global use

Tumble->tumble;

# Should we build the XS version?
my %RUN_DEPS = (
                 'perl'          => '5.008001',
                 'Sub::Exporter' => 0,
               );
my %CONFIGURE_DEPS = (
                       'ExtUtils::MakeMaker'       => '6.86',
                       'Carp'                      => 0,
                       'Class::Tiny'               => 0,
                       'Config::AutoConf'          => '0.19',
                       'Module::Pluggable::Object' => '5.1',
                     );
my %BUILD_DEPS = ();

my %TEST_DEPS = (
                  'Test::More' => 0.90,
                );
my @XS_FILES = qw(MoreUtils.xs);
#qw(Alias.xs Modern.xs Sno.xs Tassilo.xs);
#qw(lib/List/MoreUtils/Impl/Alias.xs lib/List/MoreUtils/Impl/Modern.xs lib/List/MoreUtils/Impl/Tassilo.xs);

WriteMakefile1(
    MIN_PERL_VERSION => '5.008001',
    META_ADD         => {
                  'meta-spec' => { version => 2 },
                  resources   => {
                                 repository => "https://github.com/perl5-utils/List-MoreUtils",
                               },
                  prereqs => {
                               develop => {
                                            requires => {
                                                          'Test::CPAN::Changes'                 => 0,
                                                          'Test::CheckManifest'                 => 0,
                                                          'Test::Pod'                           => 0,
                                                          'Test::Pod::Coverage'                 => 0,
                                                          'Test::Pod::Spelling::CommonMistakes' => 0,
                                                        },
                                          },
                               configure => {
                                              requires => {%CONFIGURE_DEPS},
                                            },
                               build   => { requires => {%BUILD_DEPS} },
                               test    => { requires => {%TEST_DEPS} },
                               runtime => {
                                            recommends => {
                                                            'perl' => '5.018001',
                                                          },
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
    LICENSE        => 'perl',
    PREREQ_PM      => \%RUN_DEPS,
    BUILD_REQUIRES => \%BUILD_DEPS,
    TEST_REQUIRES  => \%TEST_DEPS,
    (
       Config::AutoConf::LMU->with_xs
       ? (
           XS => { map { ( my $tgt = $_ ) =~ s/\.xs$/\.c/; $_ => $tgt; } @XS_FILES },
           MAGICXS => 1,
           #OBJECT => [ map { $_ =~ s/\.xs/\.o/; $_ } @XS_FILES ],
           #OBJECT => join(" ", map { $_ =~ s/\.xs/\.o/; $_ } @XS_FILES ),
           INC => "-I."
         )
       : ()
    ),
    depend => { '$(FIRST_MAKEFILE)' => '$(VERSION_FROM)' },
    test   => { TESTS               => 't/*.t xt/*.t gt/*/*.t' },
    # Otherwise 'cxinc' isn't defined
    DEFINE => '-DPERL_EXT',
              );

sub WriteMakefile1
{    # originally written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params       = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if ( exists( $params{EXTRA_META} ) );
    die "License not specified"    if ( !exists( $params{LICENSE} ) );
    if ( $params{TEST_REQUIRES} and ( $eumm_version < 6.6303 ) )
    {
        if ( $params{BUILD_REQUIRES} )
        {
            $params{BUILD_REQUIRES} = { %{ $params{BUILD_REQUIRES} }, %{ $params{TEST_REQUIRES} } };
        }
        else
        {
            $params{BUILD_REQUIRES} = delete $params{TEST_REQUIRES};
        }
    }
    if ( $params{BUILD_REQUIRES} and ( $eumm_version < 6.5503 ) )
    {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM} = { %{ $params{PREREQ_PM} || {} }, %{ $params{BUILD_REQUIRES} } };
        delete $params{BUILD_REQUIRES};
    }
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
        unless ( $cpan_smoker || $ENV{PERL_MM_USE_DEFAULT} || $ENV{SQL_STATEMENT_WARN_UPDATE} )
        {
            sleep 4 unless ($ok);
        }
        delete $params{CONFLICTS};
    }

    WriteMakefile(%params);
}
