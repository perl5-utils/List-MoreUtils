package List::MoreUtils;

use 5.00503;
use strict;

require Exporter;
require DynaLoader;
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
@ISA = qw(Exporter DynaLoader);

%EXPORT_TAGS = ( 
    all => [ qw(any all none notall true false firstidx lastidx insert_after insert_after_string) ],
);

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

$VERSION = '0.05';

eval {
    local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};
    bootstrap List::MoreUtils $VERSION;
    1;
};

eval <<'EOP' if not defined &any;

sub any (&@) {
    my $f = shift;
    return if ! @_;
    for (@_) {
	return 1 if $f->();
    }
    return 0;
}
    
sub all (&@) {
    my $f = shift;
    return if ! @_;
    for (@_) {
	return 0 if ! $f->();
    }
    return 1;
}

sub none (&@) {
    my $f = shift;
    return if ! @_;
    for (@_) {
	return 0 if $f->();
    }
    return 1;
}

sub notall (&@) {
    my $f = shift;
    return if ! @_;
    for (@_) {
	return 1 if ! $f->();
    }
    return 0;
}

sub true (&@) {
    my $f = shift;
    my $count = 0;
    for (@_) {
	$count++ if $f->();
    }
    return $count;
}

sub false (&@) {
    my $f = shift;
    my $count = 0;
    for (@_) {
	$count++ if ! $f->();
    }
    return $count;
}

sub firstidx (&@) {
    my $f = shift;
    for my $i (0 .. $#_) {
	local *_ = \$_[$i];	# Necessary for cases where $_[$i] holds a tied value
	return $i if $f->();
    }
    return -1;
}

sub lastidx (&@) {
    my $f = shift;
    for my $i (reverse 0 .. $#_) {
	local *_ = \$_[$i];
	return $i if $f->();
    }
    return -1;
}

sub insert_after (&$\@) {
    my ($code, $val, $list) = @_;
    my $c = -1;
    for my $i (0 .. $#$list) {
	local *_ = \$list->[$i];
	$c = $i, last if $code->();
    }
    @$list = (@{$list}[0..$c], $val, @{$list}[$c+1..$#$list]) and return 1 if $c != -1;
    return 0;
}

sub insert_after_string ($$\@) {
    my ($string, $val, $list) = @_;
    my $c = -1;
    for my $i (0 .. $#$list) {
	local $^W = 0;
	$c = $i, last if $string eq $list->[$i];
    }
    @$list = (@{$list}[0..$c], $val, @{$list}[$c+1..$#$list]) and return 1 if $c != -1;
    return 0;
}
EOP

1;
__END__

=head1 NAME

List::MoreUtils - Provide the stuff missing in List::Util

=head1 SYNOPSIS

    use List::MoreUtils qw(any all none notall true false firstidx 
                           lastidx insert_after insert_after_string);

=head1 DESCRIPTION

C<List::MoreUtils> provides some trivial but commonly needed functionality on lists
which is not going to go into C<List::Util>.

All of the below functions are implementable in one line of Perl code. Using
the functions from this module however should give slightly better performance
as everything is implemented in C. The pure-Perl implementation of these
functions only serves as a fallback in case the C portions of this module
couldn't be compiled on this machine.

=over 4

=item any BLOCK LIST

Returns a true value if any item in LIST meets the criterion given through
BLOCK. Sets C<$_> for each item in LIST in turn:

    print "At least one value undefined"
        if any { !defined($_) } @list;

Returns false otherwise, or C<undef> if LIST is empty.

=item all BLOCK LIST

Returns a true value if all items in LIST meet the criterion given through
BLOCK. Sets C<$_> for each item in LIST in turn:

    print "All items defined"
        if all { defined($_) } @list;

Returns false otherwise, or C<undef> if LIST is empty.

=item none BLOCK LIST

Logically the negation of C<any>. Returns a true value if no item in LIST meets the
criterion given through BLOCK. Sets C<$_> for each item in LIST in turn:

    print "No value defined"
        if none { defined($_) } @list;

Returns false otherwise, or C<undef> if LIST is empty.

=item notall BLOCK LIST

Logically the negation of C<all>. Returns a true value if not all items in LIST meet
the criterion given through BLOCK. Sets C<$_> for each item in LIST in turn:

    print "Not all values defined"
        if notall { defined($_) } @list;

Returns false otherwise, or C<undef> if LIST is empty.

=item true BLOCK LIST

Counts the number of elements in LIST for which the criterion in BLOCK is true. Sets C<$_> for 
each item in LIST in turn:

    printf "%i item(s) are defined", true { defined($_) } @list;

=item false BLOCK LIST

Counts the number of elements in LIST for which the criterion in BLOCK is false. Sets C<$_> for
each item in LIST in turn:

    printf "%i item(s) are not defined", false { defined($_) } @list;

=item firstidx BLOCK LIST

Returns the index of the first element in LIST for which the criterion in BLOCK is true. Sets C<$_>
for each item in LIST in turn:

    my @list = (1, 4, 3, 2, 4, 6);
    printf "item with index %i in list is 4", firstidx { $_ == 4 } @list;
    __END__
    item with index 1 in list is 4
    
Returns C<-1> if no such item could be found.

=item lastidx BLOCK LIST

Returns the index of the last element in LIST for which the criterion in BLOCK is true. Sets C<$_>
for each item in LIST in turn:

    my @list = (1, 4, 3, 2, 4, 6);
    printf "item with index %i in list is 4", lastidx { $_ == 4 } @list;
    __END__
    item with index 4 in list is 4

Returns C<-1> if no such item could be found.

=item insert_after BLOCK VALUE LIST

Inserts VALUE after the first item in LIST for which the criterion in BLOCK is true. Sets C<$_> for
each item in LIST in turn.

    my @list = qw/This is a list/;
    insert_after { $_ eq "a" } "longer" => @list;
    print "@list";
    __END__
    This is a longer list

=item insert_after_string STRING VALUE LIST

Inserts VALUE after the first item in LIST which is equal to STRING. 

    my @list = qw/This is a list/;
    insert_after_string "a", "longer" => @list;
    print "@list";
    __END__
    This is a longer list
   
=back

=head1 EXPORTS

Nothing by default. To import all of this module's symbols, do the conventional

    use List::MoreUtils qw/:all/;

It may make more sense though to only import the stuff your programs actually needs:

    use List::MoreUtils qw/any firstidx/;

=head1 VERSION

This is version 0.05.

=head1 BUGS

No known ones.

If you have a functionality that you could imagine being in this module, please
drop me a line. This module's policy will be less strict than C<List::Util>'s when
it comes to additions as it isn't a core module.

=head1 SEE ALSO

L<List::Util>

=head1 AUTHOR

Tassilo von Parseval, E<lt>tassilo.von.parseval@rwth-aachen.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Tassilo von Parseval

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
