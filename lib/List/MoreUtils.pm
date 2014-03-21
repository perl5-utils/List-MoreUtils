package List::MoreUtils;

use 5.008001;
use strict;
use warnings;
use Carp qw/carp/;

BEGIN {
    our $VERSION  = '0.400_004';
}

use Exporter::Tiny qw();
use Module::Runtime qw(use_module);
use List::MoreUtils::XS qw();    # try loading XS

our @ISA = qw(Exporter::Tiny);
our @EXPORT_OK = (
    qw(true false
      firstidx lastidx
      insert_after insert_after_string
      apply indexes
      after after_incl before before_incl
      lastval
      each_array each_arrayref
      pairwise natatime
      mesh uniq
      minmax part
      bsearch),
    # following ones have several implementations
    qw(any all none notall firstval sort_by nsort_by),
    # those are just aliases
    qw(first_index last_index first_value last_value zip distinct)
);

my @tag_hist = qw(alias sno tassilo modern);
my %pkg_tags = (
    tassilo => {
        module    => "List::MoreUtils::Impl::Tassilo",
        functions => {
            map { $_ => 1 }
              qw(any all none notall true false
              firstidx lastidx
              insert_after insert_after_string
              apply indexes
              after after_incl before before_incl
              firstval lastval
              each_array each_arrayref
              pairwise natatime
              mesh uniq
              minmax part
              bsearch)
        },
    },
    alias => {
        module    => "List::MoreUtils::Impl::Alias",
        functions => {
            map { $_ => 1 }
              qw(any all none notall
              sort_by nsort_by
              )
        },
    },
    sno => {
             module    => "List::MoreUtils::Impl::Sno",
             functions => { map { $_ => 1 } qw() },
           },
    modern => {
                module    => "List::MoreUtils::Impl::Modern",
                functions => { map { $_ => 1 } qw(any all none notall) },
              }
);

my %alias_list = (
                   first_index => "firstidx",
                   last_index  => "lastidx",
                   first_value => "firstval",
                   last_value  => "lastval",
                   zip         => "mesh",
                   distinct    => "uniq",
                 );

sub _export_tags
{
    map { $_ => [ keys %{ $pkg_tags{$_}{functions} } ] } keys %pkg_tags;
}

sub _export_alias_names
{
    alias_names => [ keys %alias_list ];
}

sub _exporter_expand_sub
{
    my ( $class, $name, $arg, $globals ) = @_;

    my @impls = ( "HASH" eq ref $arg and $arg->{impl} ) ? $arg->{impl} : @tag_hist;
    my $seek  = defined($alias_list{$name}) ? $alias_list{$name} : $name;

    foreach my $impl (@impls)
    {
        my $exp_sub;
        defined $pkg_tags{$impl}->{functions}->{$seek}
          and use_module( $pkg_tags{$impl}->{module} )
          and $exp_sub = $pkg_tags{$impl}->{module}->can($seek);
        $exp_sub and return ($name => $exp_sub);
    }

    return $class->SUPER::_exporter_expand_sub($name, $arg, $globals);
}

sub _exporter_expand_tag
{
    my ( $class, $group, $arg, $globals ) = @_;

    if ($pkg_tags{$group})
    {
        my %functions = %{ $pkg_tags{$group}->{functions} };
        $functions{$alias_list{$_}} && $functions{$_}++ for keys(%alias_list);
        return map [ $_ => { impl => $group, %{$arg||{}} } ], keys(%functions);
    }
    
    return $class->SUPER::_exporter_expand_tag($group, $arg, $globals);
}

{ List::MoreUtils->import(':all'); }

=pod

=head1 NAME

List::MoreUtils - Provide the stuff missing in List::Util

=head1 SYNOPSIS

    use List::MoreUtils qw(:tassilo); # use as initially thought
    use List::MoreUtils qw(:alias); # use alias changes
    use List::MoreUtils qw(:modern); # use compat mode to List::Util
    use List::MoreUtils qw(:sno); # use nowadays added stuff

    use List::MoreUtils qw(:all); # use all with precedence 'alias', 'sno', 'tassilo', 'modern';

    use List::MoreUtils any => { impl => 'modern' },
                        all =>  { impl => 'tassilo' },
                        'none', 'notall', # above precedence
                        'firstidx' => { impl => 'tassilo' },
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

It may make more sense though to only import the stuff your program actually
needs:

    use List::MoreUtils qw{ any firstidx };

=head2 IMPLEMENTATIONS

B<List::MoreUtils> supports several implementations of some functions. The
available ones are:

=over 4

=item tassilo

This is the original author of List::MoreUtils. His implementations shall
be default and will be probably later.

=item alias

This is a self-volunteered author who accidently broke the API of the
original author but it was recognized to late and we currently have modules
on CPAN and DarkPAN relying on the broken API. So this is the I<current>
default implementation for some time ...

=item modern

This implementation contains functions adapted by L<List::Util> since it
has a new maintainer. Unfortunately the API isn't 100% List::MoreUtils
compatible, but since List::MoreUtils provides always a pure Perl
implementation, it might be a valueable upgrade path...

=item sno

This implementation is for functions by the current author. Currently it's
empty, but I just reserve the name.

=item all

This is a precedence list of existing implementations. Currently it's
C<qw(alias sno tassilo modern)>, but the C<alias> precedence will put at
the end of the queue within some releases. Be prepared.

=back

=head2 IMPLICIT

B<List::MoreUtils> silently supported just being required in historic
versions. This support needs to be removed for cleaning up accidents of
short history.

In a close release the silent support for C<use after require> will be
discarded. First releases will show warnings before it will be removed
completely.

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

=item * Got Repository

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

L<List::Util>

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
