package Data::Tumbler;

use strict;
use warnings;

=head1 NAME

Data::Tumbler - Dynamic generation of nested combinations

=head1 SYNOPSIS

    my $tumbler = Data::Tumbler->new(
        consumer  => sub {
            my ($path, $context, $payload) = @_;
            print "@$path: @$context\n";
        },
    );

    $tumbler->tumble(
        [   # provider code refs
            sub { (foo => 42, bar => 24, baz => 19) },
            sub { (ping => 1, pong => 2) },
            # ...
        ],
        [], # names
        [], # values
        [], # payload
    );

Outputs:

    bar ping: 24 1
    bar pong: 24 2
    baz ping: 19 1
    baz pong: 19 2
    foo ping: 42 1
    foo pong: 42 2

=head1 DESCRIPTION

The tumble() method calls a sequence of 'provider' code references each of
which returns a hash.  The first provider is called and then, for each hash
item it returns, the tumble() method recurses to call the next provider.

The recursion continues until there are no more providers to call, at which
point the consumer code reference is called.  Effectively the providers create
a tree of combinations and the consumer is called at the leafs of the tree.

If a provider returns no items then that part of the tree is pruned. Further
providers, if any, are not called and the consumer is not called.

During a call to tumble() three values are passed down through the tree and
into the consumer: path, context, and payload.

The path and context are derived from the names and values of the hashes
returned by the providers. Typically the path define the current "path"
through the tree of combinations.

The providers are passed the current path, context, and payload.
The payload is cloned at each level of recursion so that any changes made to it
by providers are only visible within the scope of the generated sub-tree.

Note that although the example above shows the path, context and payload as
array references, the tumbler code makes no assumptions about them. They can be
any kinds of values.

=head1 ATTRIBUTES

=head2 consumer

    $tumbler->consumer( sub { my ($path, $context, $payload) = @_; ... } );

Defines the code reference to call at the leafs of the generated tree of combinations.
The default is to throw an exception.

=head2 add_path

    $tumbler->add_path( sub { my ($path, $name) = @_; return [ @$path, $name ] } )

Defines the code reference to call to create a new path value that combines
the existing path and the new name. The default is shown in the example above.


=head2 add_context

    $tumbler->add_context( sub { my ($context, $value) = @_; return [ @$context, $value ] } )

Defines the code reference to call to create a new context value that combines
the existing context and the new value. The default is shown in the example above.

=cut

use Storable qw(dclone);
use Carp qw(confess);

use Class::Tiny {
    consumer  => sub { confess "No Data::Tumbler consumer defined" },
    add_path    => sub { sub { my ($path,    $name ) = @_; return [ @$path,    $name  ] }},
    add_context => sub { sub { my ($context, $value) = @_; return [ @$context, $value ] }},
};


sub tumble {
    my ($self, $providers, $path, $context, $payload) = @_;

    if (not @$providers) { # no more providers in this context
        $self->consumer->($path, $context, $payload);
        return;
    }

    # clone the $payload so the provider can alter it for the consumer
    # at and below this point in the tree of variants
    $payload = dclone($payload) if ref $payload;

    my ($current_provider, @remaining_providers) = @$providers;

    # call the current provider to supply the variants for this context
    # returns empty if the consumer shouldn't be called in the current context
    # returns a single (possibly nil/empty/dummy) variant if there are
    # no actual variations needed.
    my %variants = $current_provider->($path, $context, $payload);

    # for each variant in turn, call the next level of provider
    # with the name and value of the variant appended to the
    # path and context.

    for my $name (sort keys %variants) {

        $self->tumble(
            \@remaining_providers,
            $self->add_path->($path,  $name),
            $self->add_context->($context, $variants{$name}),
            $payload,
        );
    }

    return;
}

1;
