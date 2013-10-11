#!perl

use strict;
require 5.008003;
BEGIN {
}
use Config              ();
use ExtUtils::MakeMaker ();
use lib 'inc';
use Config::AutoConf::LMU ();

# Should we build the XS version?
my $make_xs = undef;
foreach ( @ARGV ) {
	/^-pm/ and $make_xs = 0;
	/^-xs/ and $make_xs = 1;
}
unless ( defined $make_xs ) {
	$make_xs = can_xs();
}

WriteMakefile(
	NAME               => 'List::MoreUtils',
	ABSTRACT           => 'Provide the stuff missing in List::Util',
	VERSION_FROM       => 'lib/List/MoreUtils.pm',
	AUTHOR             => [ 'Tassilo von Parseval <tassilo.von.parseval@rwth-aachen.de>',
	                        'Adam Kennedy <adamk@cpan.org>' , 'Jens Rehsack <rehsack@cpan.org>' ],
	LICENSE            => 'perl',
	MIN_PERL_VERSION   => '5.008003',
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '6.52',
		'Config::AutoConf'  => '0.19',
	},
	BUILD_REQUIRES => {
		'Test::More' => '0.88',
	},
	test  => { TESTS => 't/*.t xt/*.t' },
	META_MERGE => {
	    resources => { repository => "https://github.com/perl5-utils/List-MoreUtils", },
	},

	# Special stuff
	CONFIGURE => sub {
		my $hash = $_[1];
		unless ( $make_xs ) {
			$hash->{XS} = { };
			$hash->{C}  = [ ];
		}
		return $hash;
	},

	# Otherwise 'cxinc' isn't defined 
	DEFINE => '-DPERL_EXT',
);

######################################################################
# Support Functions

# Modified from eumm-upgrade by Alexandr Ciornii.
sub WriteMakefile {
	my %params=@_;
	my $eumm_version=$ExtUtils::MakeMaker::VERSION;
	$eumm_version=eval $eumm_version;
	die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
	die "License not specified" unless exists $params{LICENSE};
	if ( $params{BUILD_REQUIRES} and $eumm_version < 6.5503 ) {
		#EUMM 6.5502 has problems with BUILD_REQUIRES
		$params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
		delete $params{BUILD_REQUIRES};
	}
	delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
	delete $params{MIN_PERL_VERSION}   if $eumm_version < 6.48;
	delete $params{META_MERGE}         if $eumm_version < 6.46;
	delete $params{META_ADD}           if $eumm_version < 6.46;
	delete $params{LICENSE}            if $eumm_version < 6.31;
	delete $params{AUTHOR}             if $] < 5.005;
	delete $params{ABSTRACT_FROM}      if $] < 5.005;
	delete $params{BINARY_LOCATION}    if $] < 5.005;
	ExtUtils::MakeMaker::WriteMakefile(%params);
}

# Secondary compile testing via ExtUtils::CBuilder
sub can_xs {
    my $autoconf = Config::AutoConf::LMU->new();
    $autoconf->check_sane_xs();
}
