package List::MoreUtils::Impl::Alias;

use 5.008001;
use strict;
use warnings;

our $VERSION   = '0.400_004';

use List::MoreUtils::XS qw(); # try load XS stuff ...

unless(defined &any)
{
    my @pp_imp = map { "*$_ = \\&List::MoreUtils::Impl::Alias::PP::$_;" }
	qw(any all none notall);
    my $pp_stuff = join( "\n", "use List::MoreUtils::Impl::Alias::PP;", @pp_imp );
    eval $pp_stuff;
    die $@ if $@;
}

sub sort_by(&@) {
    my ($code, @list) = @_;
    return map { $_->[0] }
          sort { $a->[1] cmp $b->[1] }
           map { [$_, scalar($code->())] }
               @list;
}

sub nsort_by(&@) {
    my ($code, @list) = @_;
    return map { $_->[0] }
          sort { $a->[1] <=> $b->[1] }
           map { [$_, scalar($code->())] }
               @list;
}

1;

__END__

=pod

=head1 NAME

List::MoreUtils::Impl::Alias - Provide List::MoreUtils implementation by Adam Kennedy

=head1 SYNOPSIS

  use List::MoreUtils qw(:alias);

=head1 FUNCTIONS

=head2 any BLOCK LIST

Returns a true value if any item in LIST meets the criterion given through
BLOCK. Sets C<$_> for each item in LIST in turn:

  print "At least one value undefined"
    if any { ! defined($_) } @list;

Returns false otherwise, or if LIST is empty.

B<The behaviour without LIST needs to be discussed!>

=head2 all BLOCK LIST

Returns a true value if all items in LIST meet the criterion given through
BLOCK, or if LIST is empty. Sets C<$_> for each item in LIST in turn:

  print "All items defined"
    if all { defined($_) } @list;

Returns false otherwise.

=head2 none BLOCK LIST

Logically the negation of C<any>. Returns a true value if no item in LIST meets
the criterion given through BLOCK, or if LIST is empty. Sets C<$_> for each item
in LIST in turn:

  print "No value defined"
    if none { defined($_) } @list;

Returns false otherwise.

=head2 notall BLOCK LIST

Logically the negation of C<all>. Returns a true value if not all items in LIST
meet the criterion given through BLOCK. Sets C<$_> for each item in LIST in
turn:

  print "Not all values defined"
    if notall { defined($_) } @list;

Returns false otherwise, or if LIST is empty.

=head2 sort_by BLOCK LIST

Returns the list of values sorted according to the string values returned by the
KEYFUNC block or function. A typical use of this may be to sort objects according
to the string value of some accessor, such as

  sort_by { $_->name } @people

The key function is called in scalar context, being passed each value in turn as
both $_ and the only argument in the parameters, @_. The values are then sorted
according to string comparisons on the values returned.
This is equivalent to

  sort { $a->name cmp $b->name } @people

except that it guarantees the name accessor will be executed only once per value.
One interesting use-case is to sort strings which may have numbers embedded in them
"naturally", rather than lexically.

  sort_by { s/(\d+)/sprintf "%09d", $1/eg; $_ } @strings

This sorts strings by generating sort keys which zero-pad the embedded numbers to
some level (9 digits in this case), helping to ensure the lexical sort puts them
in the correct order.

=head2 nsort_by BLOCK LIST

Similar to sort_by but compares its key values numerically.

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
