package List::MoreUtils;

use 5.008001;
use strict;
use warnings;

use XSLoader ();

use vars qw{$VERSION @ISA};

BEGIN
{
    $VERSION  = '0.400';

    # Load the XS at compile-time so that redefinition warnings will be
    # thrown correctly if the XS versions of part or indexes loaded
    eval {
	# PERL_DL_NONLAZY must be false, or any errors in loading will just
	# cause the perl code to be tested
	local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};

	XSLoader::load 'List::MoreUtils', $VERSION;
	1;

    } unless $ENV{LIST_MOREUTILS_PP};
}

1;
