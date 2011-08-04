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
	$make_xs = can_xs();
}

WriteMakefile(
	NAME               => 'List::MoreUtils',
	ABSTRACT           => 'Provide the stuff missing in List::Util',
	VERSION_FROM       => 'lib/List/MoreUtils.pm',
	AUTHOR             => 'Tassilo von Parseval <tassilo.von.parseval@rwth-aachen.de>',
	LICENSE            => 'perl',
	MIN_PERL_VERSION   => '5.00503',
	CONFIGURE_REQUIRES => {
		'ExtUtils::MakeMaker' => '6.52',
		'ExtUtils::CBuilder'  => '0.27',
	},
	BUILD_REQUIRES => {
		'Test::More' => '0.42',
	},
	PREREQ_PM => {
		'Test::More' => '0.82',
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
	# Do we have the configure_requires checker?
	local $@;
	eval "require ExtUtils::CBuilder;";
	if ( $@ ) {
		# They don't obey configure_requires, so it is
		# someone old and delicate. Try to avoid hurting
		# them by falling back to an older simpler test.
		return can_cc();
	}

	# Do a simple compile that consumes the headers we need
	my @libs    = ();
	my $object  = undef;
	my $builder = ExtUtils::CBuilder->new( quiet => 1 );
	unless ( $builder->have_compiler ) {
		# Lack of a compiler at all
		return 0;
	}
	eval {
		$object = $builder->compile(
			source => 'sanexs.c',
		);
		@libs = $builder->link(
			objects     => $object,
			module_name => 'sanexs',
		);
	};
	my $broken = !! $@;
	foreach ( $object, @libs ) {
		next unless defined $_;
		1 while unlink $_;
	}

	if ( $broken ) {
		### NOTE: Don't do this in a production release.
		# Compiler is officially screwed, you don't deserve
		# to do any of our downstream depedencies as you'll
		# probably end up choking on them as well.
		# Trigger an NA for their own protection.
		print "Unresolvable broken external dependency.\n";
		print "This package requires a C compiler with full perl headers.\n";
		print "Trivial test code using them failed to compile.\n";
		print STDERR "NA: Unable to build distribution on this platform.\n";
		exit(0);
	}

	return 1;
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
	if ( -x $_cmd or $_cmd = MM->maybe_command($_cmd) ) {
		return $_cmd;
	}

	foreach my $dir ( (split /$Config::Config{path_sep}/, $ENV{PATH}), '.' ) {
		next if $dir eq '';
		my $abs = File::Spec->catfile($dir, $cmd);
		return $abs if (-x $abs or $abs = MM->maybe_command($abs));
	}

	return;
}
