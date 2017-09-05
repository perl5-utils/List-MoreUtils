#!perl

use strict;
use warnings;

use 5.008_001;

use Config;
use ExtUtils::MakeMaker;

my @argv = @ARGV;
defined $ENV{PERL_MM_OPT} and push @argv, split " ", $ENV{PERL_MM_OPT};

my $require_xs = 1;

# Should we build the XS version?
foreach (@argv)
{
    /^-pm/
      and warn "-pm is depreciated, please use PUREPERL_ONLY=1 where applicable."
      and $require_xs = 0;
    /^-xs/ and warn "-xs is depreciated" and $require_xs = 1;
    /^PUREPERL_ONLY=(.*)$/
      and $require_xs = !$1;
}

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
    the version of module %s (%s) you have installed.

    It's strongly recommended that you update it after
    installing this version of %s.
***
EOCM

my $selfConflictMsg = <<EOSCM;
***
    This version of %s conflicts with
    the version of %s (%s) you have installed.

    It's strongly recommended that you carefully read
    the Changes file and test your application with
    this version before finally upgrading.

    See local::lib how to do it easily.
***
EOSCM

my %RUN_DEPS = (
    'Exporter::Tiny' => '0.038',
    ($require_xs ? ('List::MoreUtils::XS' => '0.423') : ())
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
            configure => {requires => {%CONFIGURE_DEPS}},
            test      => {
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
    test   => {TESTS               => join(' ', 't/*.t', 't/pureperl/*.t', ($require_xs ? 't/xs/*.t' : ()), 'xt/*.t')},
    # Otherwise 'cxinc' isn't defined
    ($] < 5.012 ? (DEFINE => '-DPERL_EXT') : (),),
);

sub CheckConflicts
{
    my %params    = @_;
    my %conflicts = %{$params{CONFLICTS}};
    my $found     = 0;
    my (@killsite, @killarch);

    while (my ($module, $version) = each(%conflicts))
    {
        undef $@;
        eval "require $module";
        next if $@;
        my $installed = eval "\$" . $module . "::VERSION";
        if ($installed le $version)
        {
            ++$found;
            my $warning =
              (0 == index($module, $params{NAME}, 0))
              ? sprintf($selfConflictMsg, $params{NAME}, $module, $installed)
              : sprintf($conflictMsg, $params{NAME}, $module, $installed, $params{NAME});
            warn $warning;
            (my $modfile = "${module}.pm") =~ s,::,/,g;
            if (index($INC{$modfile}, $Config{installsitearch}) == 0)
            {
                push @killarch, $modfile;
            }
            elsif (index($INC{$modfile}, $Config{installsitelib}) == 0)
            {
                push @killsite, "${modfile}.pm";
            }
        }
    }

    if (@killsite or @killarch)
    {
        package MY;
        no warnings 'once';

        *install = sub {
            my $self = shift;
            return join("\n",
                "\npure_site_install ::",
                (map { '	$(NOECHO) $(RM_F) ' . $self->quote_literal($self->catfile('$(DESTINSTALLSITELIB)',  $_)) } @killsite),
                (map { '	$(NOECHO) $(RM_F) ' . $self->quote_literal($self->catfile('$(DESTINSTALLSITEARCH)', $_)) } @killarch),
                $self->SUPER::install);
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
