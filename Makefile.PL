use strict;
BEGIN {
	require 5.00503;
}
use Config              ();
use ExtUtils::MakeMaker ();

# Should we build the XS version?
my $make_xs = undef;
foreach ( @ARGV ) {
	/^-pm/ and $make_xs = 0;
	/^-xs/ and $make_xs = 1;
}
unless ( defined $make_xs ) {
	$make_xs = can_cc();
}

WriteMakefile(
	NAME         => 'List::MoreUtils',
	ABSTRACT     => 'Provide the stuff missing in List::Util', 
	VERSION_FROM => 'lib/List/MoreUtils.pm', 
	AUTHOR	     => 'Tassilo von Parseval <tassilo.von.parseval@rwth-aachen.de>',
	LICENSE      => 'perl',
	DEFINE       => '-DPERL_EXT',	# otherwise 'cxinc' isn't defined 
	PREREQ_PM    => { },
	CONFIGURE    => sub {
		my $hash = $_[1];
		unless ( $make_xs ) {
			$hash->{XS} = { };
			$hash->{C}  = [ ];
		}
		return $hash;
	},
);






######################################################################
# Support Functions

sub WriteMakefile {
	my %params = @_;
	my $eumm_version = $ExtUtils::MakeMaker::VERSION;
	$eumm_version = eval $eumm_version;
	die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
	die "License not specified" unless exists $params{LICENSE};
	if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
		#EUMM 6.5502 has problems with BUILD_REQUIRES
		$params{PREREQ_PM} = {
			%{$params{PREREQ_PM} || {}},
			%{$params{BUILD_REQUIRES}}
		};
		delete $params{BUILD_REQUIRES};
	}
	delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
	delete $params{MIN_PERL_VERSION}   if $eumm_version < 6.48;
	delete $params{META_MERGE}         if $eumm_version < 6.46;
	delete $params{LICENSE}            if $eumm_version < 6.31;
	delete $params{AUTHOR}             if $] < 5.005;

	ExtUtils::MakeMaker::WriteMakefile(%params);
}

sub can_cc {
	my @chunks = split(/ /, $Config::Config{cc}) or return;

	# $Config{cc} may contain args; try to find out the program part
	while ( @chunks ) {
		return can_run("@chunks") || (pop(@chunks), next);
	}

	return;
}

sub can_run {
	my ($cmd) = @_;

	my $_cmd = $cmd;
	return $_cmd if (-x $_cmd or $_cmd = MM->maybe_command($_cmd));

	for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
		next if $dir eq '';
		my $abs = File::Spec->catfile($dir, $cmd);
		return $abs if (-x $abs or $abs = MM->maybe_command($abs));
	}

	return;
}
