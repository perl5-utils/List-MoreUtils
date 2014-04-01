package List::MoreUtils;

use 5.008001;
use strict;
use warnings;

BEGIN
{
    our $VERSION = '0.400_006';
}

use Exporter::Tiny qw();
use List::MoreUtils::XS qw();    # try loading XS

my @functions = (
    qw(any all none notall
      any_u all_u none_u notall_u
      true false
      firstidx lastidx
      insert_after insert_after_string
      apply indexes
      after after_incl before before_incl
      firstval lastval
      each_array each_arrayref
      pairwise natatime
      mesh uniq
      minmax part
      sort_by nsort_by bsearch
      ),
);

my %pkg_tags = (
                 all => { map { $_ => 1 } @functions },
               );

my %alias_list = (
                   first_index => "firstidx",
                   last_index  => "lastidx",
                   first_value => "firstval",
                   last_value  => "lastval",
                   zip         => "mesh",
                   distinct    => "uniq",
                 );

our @ISA = qw(Exporter::Tiny);
our @EXPORT_OK = ( @functions, keys %alias_list );

sub _export_tags
{
    map { $_ => [ keys %{ $pkg_tags{$_} } ] } keys %pkg_tags;
}

sub _export_alias_names
{
    alias_names => [ keys %alias_list ];
}

sub _exporter_expand_sub
{
    my ( $class, $name, $arg, $globals ) = @_;

    my @impls = ( "HASH" eq ref $arg and $arg->{impl} ) ? $arg->{impl} : 'all';
    my $seek = defined( $alias_list{$name} ) ? $alias_list{$name} : $name;

    foreach my $impl (@impls)
    {
        my $exp_sub;
        defined $pkg_tags{$impl}->{$seek}
          and $exp_sub = __PACKAGE__->can($seek);
        $exp_sub and return ( $name => $exp_sub );
    }

    return $class->SUPER::_exporter_expand_sub( $name, $arg, $globals );
}

sub _exporter_expand_tag
{
    my ( $class, $group, $arg, $globals ) = @_;
    my %funcs;

    if ( $pkg_tags{$group} )
    {
        my %functions = %{ $pkg_tags{$group} };
        $functions{ $alias_list{$_} } && $functions{$_}++ for keys(%alias_list);
        %funcs = map { $_ => { impl => $group, %{ $arg || {} } } } keys(%functions);
    }

    %funcs and return map [ $_ => $funcs{$_} ], keys(%funcs);
    return $class->SUPER::_exporter_expand_tag( $group, $arg, $globals );
}

{ List::MoreUtils->import(':all'); }

=pod

=head1 NAME

List::MoreUtils - Provide the stuff missing in List::Util

=head1 SYNOPSIS

    use List::MoreUtils qw(:strict); # use as initially thought
    use List::MoreUtils qw(:relax); # use alias changes
    use List::MoreUtils qw(:modern); # use compat mode to List::Util

    use List::MoreUtils qw(:all); # use all with precedence 'relax', 'strict', 'modern';

    use List::MoreUtils any => { impl => 'modern' },
                        all =>  { impl => 'strict' },
                        'none', 'notall', # currently ':all' precedence
                        'firstidx' => { impl => 'strict' },
                        all => { impl => 'modern', as => 'modern_all' };

=head1 DESCRIPTION

B<List::MoreUtils> provides some trivial but commonly needed functionality on
lists which is not going to go into L<List::Util>.

All of the below functions are implementable in only a couple of lines of Perl
code. Using the functions from this module however should give slightly better
performance as everything is implemented in C. The pure-Perl implementation of
these functions only serves as a fallback in case the C portions of this module
couldn't be compiled on this machine.

=head1 EXPORTS

Nothing by default. To import all of this module's symbols, do the conventional

    use List::MoreUtils ':all';

or

    use List::MoreUtils ':default';

It may make more sense though to only import the stuff your program actually
needs:

    use List::MoreUtils qw{ any firstidx };

=head1 FUNCTIONS

=head2 any BLOCK LIST

Returns a true value if any item in LIST meets the criterion given through
BLOCK. Sets C<$_> for each item in LIST in turn:

  print "At least one value undefined"
    if any { ! defined($_) } @list;

Returns false otherwise, or if LIST is empty.

B<The behaviour without LIST needs to be discussed!>

=head2 any_u BLOCK LIST

Returns a true value if any item in LIST meets the criterion given through
BLOCK. Sets C<$_> for each item in LIST in turn:

  print "At least one value undefined"
    if any { ! defined($_) } @list;

Returns false otherwise, or undef if LIST is empty.

=head2 all BLOCK LIST

Returns a true value if all items in LIST meet the criterion given through
BLOCK, or if LIST is empty. Sets C<$_> for each item in LIST in turn:

  print "All items defined"
    if all { defined($_) } @list;

Returns false otherwise.

=head2 all_u BLOCK LIST

Returns a true value if all items in LIST meet the criterion given through
BLOCK, or if LIST is empty. Sets C<$_> for each item in LIST in turn:

  print "All items defined"
    if all { defined($_) } @list;

Returns false otherwise, or undef if LIST is empty.

=head2 none BLOCK LIST

Logically the negation of C<any>. Returns a true value if no item in LIST meets
the criterion given through BLOCK, or if LIST is empty. Sets C<$_> for each item
in LIST in turn:

  print "No value defined"
    if none { defined($_) } @list;

Returns false otherwise.

=head2 none_u BLOCK LIST

Logically the negation of C<any>. Returns a true value if no item in LIST meets
the criterion given through BLOCK, or if LIST is empty. Sets C<$_> for each item
in LIST in turn:

  print "No value defined"
    if none { defined($_) } @list;

Returns false otherwise, or undef if LIST is empty.

=head2 notall BLOCK LIST

Logically the negation of C<all>. Returns a true value if not all items in LIST
meet the criterion given through BLOCK. Sets C<$_> for each item in LIST in
turn:

  print "Not all values defined"
    if notall { defined($_) } @list;

Returns false otherwise, or if LIST is empty.

=head2 notall_u BLOCK LIST

Logically the negation of C<all>. Returns a true value if not all items in LIST
meet the criterion given through BLOCK. Sets C<$_> for each item in LIST in
turn:

  print "Not all values defined"
    if notall { defined($_) } @list;

Returns false otherwise, or undef if LIST is empty.

=head2 true BLOCK LIST

Counts the number of elements in LIST for which the criterion in BLOCK is true.
Sets C<$_> for  each item in LIST in turn:

  printf "%i item(s) are defined", true { defined($_) } @list;

=head2 false BLOCK LIST

Counts the number of elements in LIST for which the criterion in BLOCK is false.
Sets C<$_> for each item in LIST in turn:

  printf "%i item(s) are not defined", false { defined($_) } @list;

=head2 firstidx BLOCK LIST

=head2 first_index BLOCK LIST

Returns the index of the first element in LIST for which the criterion in BLOCK
is true. Sets C<$_> for each item in LIST in turn:

  my @list = (1, 4, 3, 2, 4, 6);
  printf "item with index %i in list is 4", firstidx { $_ == 4 } @list;
  __END__
  item with index 1 in list is 4
    
Returns C<-1> if no such item could be found.

C<first_index> is an alias for C<firstidx>.

=head2 lastidx BLOCK LIST

=head2 last_index BLOCK LIST

Returns the index of the last element in LIST for which the criterion in BLOCK
is true. Sets C<$_> for each item in LIST in turn:

  my @list = (1, 4, 3, 2, 4, 6);
  printf "item with index %i in list is 4", lastidx { $_ == 4 } @list;
  __END__
  item with index 4 in list is 4

Returns C<-1> if no such item could be found.

C<last_index> is an alias for C<lastidx>.

=head2 insert_after BLOCK VALUE LIST

Inserts VALUE after the first item in LIST for which the criterion in BLOCK is
true. Sets C<$_> for each item in LIST in turn.

  my @list = qw/This is a list/;
  insert_after { $_ eq "a" } "longer" => @list;
  print "@list";
  __END__
  This is a longer list

=head2 insert_after_string STRING VALUE LIST

Inserts VALUE after the first item in LIST which is equal to STRING. 

  my @list = qw/This is a list/;
  insert_after_string "a", "longer" => @list;
  print "@list";
  __END__
  This is a longer list

=head2 apply BLOCK LIST

Applies BLOCK to each item in LIST and returns a list of the values after BLOCK
has been applied. In scalar context, the last element is returned.  This
function is similar to C<map> but will not modify the elements of the input
list:

  my @list = (1 .. 4);
  my @mult = apply { $_ *= 2 } @list;
  print "\@list = @list\n";
  print "\@mult = @mult\n";
  __END__
  @list = 1 2 3 4
  @mult = 2 4 6 8

Think of it as syntactic sugar for

  for (my @mult = @list) { $_ *= 2 }

=head2 before BLOCK LIST

Returns a list of values of LIST up to (and not including) the point where BLOCK
returns a true value. Sets C<$_> for each element in LIST in turn.

=head2 before_incl BLOCK LIST

Same as C<before> but also includes the element for which BLOCK is true.

=head2 after BLOCK LIST

Returns a list of the values of LIST after (and not including) the point
where BLOCK returns a true value. Sets C<$_> for each element in LIST in turn.

  @x = after { $_ % 5 == 0 } (1..9);    # returns 6, 7, 8, 9

=head2 after_incl BLOCK LIST

Same as C<after> but also includes the element for which BLOCK is true.

=head2 indexes BLOCK LIST

Evaluates BLOCK for each element in LIST (assigned to C<$_>) and returns a list
of the indices of those elements for which BLOCK returned a true value. This is
just like C<grep> only that it returns indices instead of values:

  @x = indexes { $_ % 2 == 0 } (1..10);   # returns 1, 3, 5, 7, 9

=head2 firstval BLOCK LIST

=head2 first_value BLOCK LIST

Returns the first element in LIST for which BLOCK evaluates to true. Each
element of LIST is set to C<$_> in turn. Returns C<undef> if no such element
has been found.

C<first_val> is an alias for C<firstval>.

=head2 lastval BLOCK LIST

=head2 last_value BLOCK LIST

Returns the last value in LIST for which BLOCK evaluates to true. Each element
of LIST is set to C<$_> in turn. Returns C<undef> if no such element has been
found.

C<last_val> is an alias for C<lastval>.

=head2 pairwise BLOCK ARRAY1 ARRAY2

Evaluates BLOCK for each pair of elements in ARRAY1 and ARRAY2 and returns a
new list consisting of BLOCK's return values. The two elements are set to C<$a>
and C<$b>.  Note that those two are aliases to the original value so changing
them will modify the input arrays.

  @a = (1 .. 5);
  @b = (11 .. 15);
  @x = pairwise { $a + $b } @a, @b;	# returns 12, 14, 16, 18, 20

  # mesh with pairwise
  @a = qw/a b c/;
  @b = qw/1 2 3/;
  @x = pairwise { ($a, $b) } @a, @b;	# returns a, 1, b, 2, c, 3

=head2 each_array ARRAY1 ARRAY2 ...

Creates an array iterator to return the elements of the list of arrays ARRAY1,
ARRAY2 throughout ARRAYn in turn.  That is, the first time it is called, it
returns the first element of each array.  The next time, it returns the second
elements.  And so on, until all elements are exhausted.

This is useful for looping over more than one array at once:

  my $ea = each_array(@a, @b, @c);
  while ( my ($a, $b, $c) = $ea->() )   { .... }

The iterator returns the empty list when it reached the end of all arrays.

If the iterator is passed an argument of 'C<index>', then it returns
the index of the last fetched set of values, as a scalar.

=head2 each_arrayref LIST

Like each_array, but the arguments are references to arrays, not the
plain arrays.

=head2 natatime EXPR, LIST

Creates an array iterator, for looping over an array in chunks of
C<$n> items at a time.  (n at a time, get it?).  An example is
probably a better explanation than I could give in words.

Example:

  my @x = ('a' .. 'g');
  my $it = natatime 3, @x;
  while (my @vals = $it->())
  {
    print "@vals\n";
  }

This prints

  a b c
  d e f
  g

=head2 mesh ARRAY1 ARRAY2 [ ARRAY3 ... ]

=head2 zip ARRAY1 ARRAY2 [ ARRAY3 ... ]

Returns a list consisting of the first elements of each array, then
the second, then the third, etc, until all arrays are exhausted.

Examples:

  @x = qw/a b c d/;
  @y = qw/1 2 3 4/;
  @z = mesh @x, @y;	    # returns a, 1, b, 2, c, 3, d, 4

  @a = ('x');
  @b = ('1', '2');
  @c = qw/zip zap zot/;
  @d = mesh @a, @b, @c;   # x, 1, zip, undef, 2, zap, undef, undef, zot

C<zip> is an alias for C<mesh>.

=head2 uniq LIST

=head2 distinct LIST

Returns a new list by stripping duplicate values in LIST. The order of
elements in the returned list is the same as in LIST. In scalar context,
returns the number of unique elements in LIST.

    my @x = uniq 1, 1, 2, 2, 3, 5, 3, 4; # returns 1 2 3 5 4
    my $x = uniq 1, 1, 2, 2, 3, 5, 3, 4; # returns 5

=head2 minmax LIST

Calculates the minimum and maximum of LIST and returns a two element list with
the first element being the minimum and the second the maximum. Returns the
empty list if LIST was empty.

The C<minmax> algorithm differs from a naive iteration over the list where each
element is compared to two values being the so far calculated min and max value
in that it only requires 3n/2 - 2 comparisons. Thus it is the most efficient
possible algorithm.

However, the Perl implementation of it has some overhead simply due to the fact
that there are more lines of Perl code involved. Therefore, LIST needs to be
fairly big in order for C<minmax> to win over a naive implementation. This
limitation does not apply to the XS version.

=head2 part BLOCK LIST

Partitions LIST based on the return value of BLOCK which denotes into which
partition the current value is put.

Returns a list of the partitions thusly created. Each partition created is a
reference to an array.

  my $i = 0;
  my @part = part { $i++ % 2 } 1 .. 8;   # returns [1, 3, 5, 7], [2, 4, 6, 8]

You can have a sparse list of partitions as well where non-set partitions will
be undef:

  my @part = part { 2 } 1 .. 10;	    # returns undef, undef, [ 1 .. 10 ]

Be careful with negative values, though:

  my @part = part { -1 } 1 .. 10;
  __END__
  Modification of non-creatable array value attempted, subscript -1 ...

Negative values are only ok when they refer to a partition previously created:

  my @idx  = ( 0, 1, -1 );
  my $i    = 0;
  my @part = part { $idx[$++ % 3] } 1 .. 8; # [1, 4, 7], [2, 3, 5, 6, 8]

=head2 bsearch BLOCK LIST

Performs a binary search on LIST which must be a sorted list of values. BLOCK
must return a negative value if the current element (stored in C<$_>) is smaller,
a positive value if it is bigger and zero if it matches.

Returns a boolean value in scalar context. In list context, it returns the element
if it was found, otherwise the empty list.

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

=head1 ENVIRONMENT

When C<LIST_MOREUTILS_PP> is set, the module will always use the pure-Perl
implementation and not the XS one. This environment variable is really just
there for the test-suite to force testing the Perl implementation, and possibly
for reporting of bugs. I don't see any reason to use it in a production
environment.

=head1 BUGS

There is a problem with a bug in 5.6.x perls. It is a syntax error to write
things like:

    my @x = apply { s/foo/bar/ } qw{ foo bar baz };

It has to be written as either

    my @x = apply { s/foo/bar/ } 'foo', 'bar', 'baz';

or

    my @x = apply { s/foo/bar/ } my @dummy = qw/foo bar baz/;

Perl 5.5.x and Perl 5.8.x don't suffer from this limitation.

If you have a functionality that you could imagine being in this module, please
drop me a line. This module's policy will be less strict than L<List::Util>'s
when it comes to additions as it isn't a core module.

When you report bugs, it would be nice if you could additionally give me the
output of your program with the environment variable C<LIST_MOREUTILS_PP> set
to a true value. That way I know where to look for the problem (in XS,
pure-Perl or possibly both).

=head1 SUPPORT

Bugs should always be submitted via the CPAN bug tracker.

You can find documentation for this module with the perldoc command.

    perldoc List::MoreUtils

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=List-MoreUtils>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/List-MoreUtils>

=item * CPAN Ratings

L<http://cpanratings.perl.org/l/List-MoreUtils>

=item * CPAN Search

L<http://search.cpan.org/dist/List-MoreUtils/>

=item * Git Repository

L<https://github.com/perl5-utils/List-MoreUtils>

=back

=head2 Where can I go for help?

If you have a bug report, a patch or a suggestion, please open a new
report ticket at CPAN (but please check previous reports first in case
your issue has already been addressed).

Report tickets should contain a detailed description of the bug or
enhancement request and at least an easily verifiable way of
reproducing the issue or fix. Patches are always welcome, too - and
it's cheap to send pull-requests on GitHub. Please keep in mind that
code changes are more likely accepted when they're bundled with an
approving test.

If you think you've found a bug then please read
"How to Report Bugs Effectively" by Simon Tatham:
L<http://www.chiark.greenend.org.uk/~sgtatham/bugs.html>.

=head2 Where can I go for help with a concrete version?

Bugs and feature requests are accepted against the latest version
only. To get patches for earlier versions, you need to get an
agreement with a developer of your choice - who may or not report the
issue and a suggested fix upstream (depends on the license you have
chosen).

=head2 Business support and maintenance

For business support you can contact Jens via his CPAN email
address rehsackATcpan.org. Please keep in mind that business
support is neither available for free nor are you eligible to
receive any support based on the license distributed with this
package.

=head1 THANKS

=head2 Tassilo von Parseval

Credits go to a number of people: Steve Purkis for giving me namespace advice
and James Keenan and Terrence Branno for their effort of keeping the CPAN
tidier by making L<List::Utils> obsolete.

Brian McCauley suggested the inclusion of apply() and provided the pure-Perl
implementation for it.

Eric J. Roode asked me to add all functions from his module C<List::MoreUtil>
into this one. With minor modifications, the pure-Perl implementations of those
are by him.

The bunch of people who almost immediately pointed out the many problems with
the glitchy 0.07 release (Slaven Rezic, Ron Savage, CPAN testers).

A particularly nasty memory leak was spotted by Thomas A. Lowery.

Lars Thegler made me aware of problems with older Perl versions.

Anno Siegel de-orphaned each_arrayref().

David Filmer made me aware of a problem in each_arrayref that could ultimately
lead to a segfault.

Ricardo Signes suggested the inclusion of part() and provided the
Perl-implementation.

Robin Huston kindly fixed a bug in perl's MULTICALL API to make the
XS-implementation of part() work.

=head2 Jens Rehsack

Credits goes to all people contributing feedback during the v0.400
development releases, especially David Golden who spent a lot of effort
to develop a design to support current state of CPAN as well as ancient
software somewhere in the dark.

=head1 TODO

A pile of requests from other people is still pending further processing in
my mailbox. This includes:

=over 4

=item * List::Util export pass-through

Allow B<List::MoreUtils> to pass-through the regular L<List::Util>
functions to end users only need to C<use> the one module.

=item * uniq_by(&@)

Use code-reference to extract a key based on which the uniqueness is
determined. Suggested by Aaron Crane.

=item * delete_index

=item * random_item

=item * random_item_delete_index

=item * list_diff_hash

=item * list_diff_inboth

=item * list_diff_infirst

=item * list_diff_insecond

These were all suggested by Dan Muey.

=item * listify

Always return a flat list when either a simple scalar value was passed or an
array-reference. Suggested by Mark Summersault.

=back

=head1 SEE ALSO

L<List::Util>, L<List::AllUtils>, L<List::UtilsBy>

L<List::MoreUtils::ButMaintained::Sanely> for everyone who understand
"sane" equals to "everything but break my code". Please bug there.

=head1 AUTHOR

Jens Rehsack E<lt>rehsack AT cpan.orgE<gt>

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

Tassilo von Parseval E<lt>tassilo.von.parseval@rwth-aachen.deE<gt>

=head1 COPYRIGHT AND LICENSE

Some parts copyright 2011 Aaron Crane.

Copyright 2004 - 2010 by Tassilo von Parseval

Copyright 2013 - 2014 by Jens Rehsack

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;
