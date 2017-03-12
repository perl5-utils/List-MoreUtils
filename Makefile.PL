#!perl

use strict;
use warnings;

use 5.008_001;

use ExtUtils::MakeMaker;

BEGIN
{
    if (-d "Sandbox")
    {
        unless (grep { $_ eq "." } @INC)
        {
            use lib ".";
        }
        eval "use Sandbox::Tumble ();";
        $@ and die $@;
        eval "use File::Path ();";
        File::Path->import;
        -d 't/pureperl' and rmtree('t/pureperl');
        Sandbox::Tumble->tumble(qw(t));
    }
}

my @argv = @ARGV;
defined $ENV{PERL_MM_OPT} and push @argv, split " ", $ENV{PERL_MM_OPT};

my $want_xs = {"List::MoreUtils::XS" => "0.416"};
foreach (@ARGV)
{
    /^-pm/ and warn "-pm is depreciated, please use PUREPERL_ONLY=1" and $want_xs = {};
    /^-xs/ and warn "-xs is depreciated, building XS is default anyway" and $want_xs = {"List::MoreUtils::XS" => "0.416"};
    /^PUREPERL_ONLY=(.*)$/ and $want_xs = int($1) ? {} : {"List::MoreUtils::XS" => "0.416"};
}

# Should we build the XS version?
my %RUN_DEPS = (
    'Exporter::Tiny' => '0.038',
);
my %CONFIGURE_DEPS = (
    'ExtUtils::MakeMaker' => 0,
);
my %TEST_DEPS = (
    'Test::More' => 0.96,
);

WriteMakefile1(
    META_MERGE => {
        'meta-spec' => {version => 2},
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
            license => 'apache_2_0',
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
                },
            },
            configure => {requires => {%CONFIGURE_DEPS}},
            test      => {
                requires   => {%TEST_DEPS},
                recommends => {'Test::LeakTrace' => 0}
            },
            runtime => {
                requires   => {%RUN_DEPS},
                recommends => $want_xs
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
    TEST_REQUIRES      => \%TEST_DEPS,
    (-d "Sandbox" ? (realclean => {FILES => "t/pureperl"}) : ()),
    depend => {'$(FIRST_MAKEFILE)' => '$(VERSION_FROM)'},
    test   => {TESTS               => join(' ', 't/*.t', 't/pureperl/*.t', 'xt/*.t')},
    # Otherwise 'cxinc' isn't defined
    ($] < 5.012 ? (DEFINE => '-DPERL_EXT') : (),),
);

sub WriteMakefile1
{    # originally written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params       = @_;
    my $eumm_version = $ExtUtils::MakeMaker::VERSION;
    $eumm_version = eval $eumm_version;
    die "EXTRA_META is deprecated" if (exists($params{EXTRA_META}));
    die "License not specified"    if (!exists($params{LICENSE}));
    $params{TEST_REQUIRES}
      and $eumm_version < 6.6303
      and $params{BUILD_REQUIRES} = {%{$params{BUILD_REQUIRES} || {}}, %{delete $params{TEST_REQUIRES}}};
    #EUMM 6.5502 has problems with BUILD_REQUIRES
    $params{BUILD_REQUIRES}
      and $eumm_version < 6.5503
      and $params{PREREQ_PM} = {%{$params{PREREQ_PM} || {}}, %{delete $params{BUILD_REQUIRES}}};
    ref $params{AUTHOR}
      and "ARRAY" eq ref $params{AUTHOR}
      and $eumm_version < 6.5702
      and $params{AUTHOR} = join(", ", @{$params{AUTHOR}});
    delete $params{CONFIGURE_REQUIRES}    if ($eumm_version < 6.52);
    delete $params{MIN_PERL_VERSION}      if ($eumm_version < 6.48);
    delete $params{META_MERGE}            if ($eumm_version < 6.46);
    delete $params{META_ADD}{prereqs}     if ($eumm_version < 6.58);
    delete $params{META_ADD}{'meta-spec'} if ($eumm_version < 6.58);
    delete $params{META_ADD}              if ($eumm_version < 6.46);
    delete $params{LICENSE}               if ($eumm_version < 6.31);
    delete $params{AUTHOR}                if ($] < 5.005);
    delete $params{ABSTRACT_FROM}         if ($] < 5.005);
    delete $params{BINARY_LOCATION}       if ($] < 5.005);

    # more or less taken from Moose' Makefile.PL
    if ($params{CONFLICTS})
    {
        my $ok = CheckConflicts(%params);
        exit(0) if ($params{PREREQ_FATAL} and not $ok);
        my $cpan_smoker = grep { $_ =~ m/(?:CR_SMOKER|CPAN_REPORTER|AUTOMATED_TESTING)/ } keys %ENV;
        unless ($cpan_smoker || $ENV{PERL_MM_USE_DEFAULT})
        {
            sleep 4 unless ($ok);
        }
        delete $params{CONFLICTS};
    }

    WriteMakefile(%params);
}
