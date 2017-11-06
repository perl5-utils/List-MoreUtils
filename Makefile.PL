#!perl

use strict;
use warnings;

use 5.008_001;

use Config;
use ExtUtils::MakeMaker;

BEGIN
{
    unless (grep { $_ eq "." } @INC)
    {
        use lib ".";
    }
}

use inc::latest 'Capture::Tiny';
use inc::latest 'Config::AutoConf';

if (inc::latest->can("write"))
{
    inc::latest->write("inc");
    for my $mod (inc::latest->loaded_modules)
    {
        inc::latest->bundle_module($mod, "inc");
    }
}

use inc::Config::AutoConf::LMU ();

inc::Config::AutoConf::LMU->_set_argv(@ARGV);    # XXX hack because we cannot construct for global use
my $loadable_xs = inc::Config::AutoConf::LMU->check_produce_loadable_xs_build();

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
    -d 't/xs'       and rmtree('t/xs');
    -d 't/pureperl' and rmtree('t/pureperl');
    Sandbox::Tumble->tumble(qw(t));
}

my $conflictMsg = <<EOCM;
***
    This version of %s conflicts with
    the version of module %s v%s you have installed.

    It's strongly recommended that you update it after
    installing this version of %s.
***
EOCM

my $selfConflictMsg = <<EOSCM;
***
    This version of %s conflicts with the version of
    %s v%s at %s you have installed.

    It's strongly recommended that you carefully read
    the Changes file and test your application with
    this version before finally upgrading.

    The installed files will be removed when installing.
***
EOSCM

my %RUN_DEPS = (
    'Exporter::Tiny' => '0.038',
    ($loadable_xs ? ('List::MoreUtils::XS' => '0.426') : ())
);
my %BUNDLE_CONFIGURE_DEPS = (
    'inc::latest'      => '0.500',
    'Config::AutoConf' => '0.315',
);
my %CONFIGURE_DEPS = (
    'ExtUtils::MakeMaker' => 0,
);
my %TEST_DEPS = (
    'Storable'   => 0,
    'Test::More' => 0.96,
);
my %CONFLICTS = (
    'List::MoreUtils'     => '0.416',
    'List::MoreUtils::PP' => '0.416',
    'List::MoreUtils::XS' => '0.416',
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
                    %BUNDLE_CONFIGURE_DEPS,
                    'Test::CPAN::Changes'                 => 0,
                    'Test::CheckManifest'                 => 0,
                    'Module::CPANTS::Analyse'             => '0.96',
                    'Test::Kwalitee'                      => 0,
                    'Test::Pod'                           => 0,
                    'Test::Pod::Coverage'                 => 0,
                    'Test::Pod::Spelling::CommonMistakes' => 0,
                    'Test::Spelling'                      => 0,
                    'Test::WriteVariants'                 => '0.014',
                },
            },
            configure => {
                requires   => {%CONFIGURE_DEPS},
                recommends => {'Config::AutoConf' => '0.315'}
            },
            test => {
                requires => {%TEST_DEPS},
                requires => {'Test::LeakTrace' => 0}
            },
            runtime => {requires => {%RUN_DEPS}},
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
    LICENSE            => 'apache_2_0',
    CONFIGURE_REQUIRES => \%CONFIGURE_DEPS,
    CONFLICTS          => \%CONFLICTS,
    PREREQ_PM          => \%RUN_DEPS,
    TEST_REQUIRES      => \%TEST_DEPS,
    (-d "Sandbox" ? (realclean => {FILES => "t/pureperl t/xs M*.bak"}) : ()),
    depend => {'$(FIRST_MAKEFILE)' => '$(VERSION_FROM)'},
    test   => {TESTS               => join(' ', 't/*.t', 't/pureperl/*.t', ($loadable_xs ? 't/xs/*.t' : ()), 'xt/*.t')},
    # Otherwise 'cxinc' isn't defined
    ($] < 5.012 ? (DEFINE => '-DPERL_EXT') : (),),
);

sub CheckConflicts
{
    my %params    = @_;
    my %conflicts = %{$params{CONFLICTS}};
    my $found     = 0;
    my @kill;

    while (my ($module, $version) = each(%conflicts))
    {
        undef $@;
        eval "require $module";
        next if $@;
        my $installed = eval "\$" . $module . "::VERSION";
        if ($installed le $version)
        {
            ++$found;
            if ($module eq "List::MoreUtils" or $module eq "List::MoreUtils::PP")
            {
                (my $modfile = "${module}.pm") =~ s,::,/,g;
                warn sprintf($selfConflictMsg, $params{NAME}, $module, $installed, $INC{$modfile});
                push @kill, $modfile;
            }
            else
            {
                warn sprintf($conflictMsg, $params{NAME}, $module, $installed, $params{NAME});
            }

        }
    }

    if (@kill)
    {

        package MY;
        no warnings 'once';

        *install = sub {
            my $self = shift;
            return "\npure_site_install ::\n"
              . join("",
                map { "\t\$(NOECHO) \$(RM_F) " . $self->quote_literal($self->catfile('$(DESTINSTALLSITEARCH)', $_)) . "\n" }
                  @kill)
              . $self->SUPER::install;
        };
    }

    return !$found;
}

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

    # more or less taken from SQL::Statement's Makefile.PL
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
