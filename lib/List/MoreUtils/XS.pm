package List::MoreUtils::XS;

use 5.008001;
use strict;
use warnings;

use vars qw{$VERSION @ISA};

BEGIN
{
    $VERSION  = '0.400';

    # Load the XS at compile-time so that redefinition warnings will be
    # thrown correctly if the XS versions of part or indexes loaded
    my $ldr = <<EOLDR;
	package List::MoreUtils;

	# PERL_DL_NONLAZY must be false, or any errors in loading will just
	# cause the perl code to be tested
	local \$ENV{PERL_DL_NONLAZY} = 0 if \$ENV{PERL_DL_NONLAZY};

	use XSLoader;
	XSLoader::load();

	1;
EOLDR

    eval $ldr unless $ENV{LIST_MOREUTILS_PP};
    $@ and die $@;
}

1;
