package List::MoreUtils::Impl::Alias::PP;

use strict;
use warnings;

our $VERSION   = '0.400_004';

=pod

=head1 NAME

List::MoreUtils::Impl::Alias::PP - Provide List::MoreUtils implementation by Adam Kennedy

=head1 SYNOPSIS

  BEGIN { $ENV{LIST_MOREUTILS_PP} = 1; }
  use List::MoreUtils qw(:alias);

=cut

# Use pure scalar boolean return values for compatibility with XS
sub any (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 1 if $f->();
    }
    return 0;
}

sub all (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 0 unless $f->();
    }
    return 1;
}

sub none (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 0 if $f->();
    }
    return 1;
}

sub notall (&@) {
    my $f = shift;
    foreach ( @_ ) {
        return 1 unless $f->();
    }
    return 0;
}

=head1 SEE ALSO

L<List::Util>

=head1 AUTHOR

Jens Rehsack E<lt>rehsack AT cpan.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

Tassilo von Parseval E<lt>tassilo.von.parseval@rwth-aachen.deE<gt>

=head1 COPYRIGHT AND LICENSE

Some parts copyright 2011 Aaron Crane.

Copyright 2004 - 2010 by Tassilo von Parseval
Copyright 2013 by Jens Rehsack

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
