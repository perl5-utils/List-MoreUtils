package List::MoreUtils;

use 5.008001;
use strict;
use warnings;

use Module::Runtime qw(use_module);
use List::MoreUtils::XS qw(); # try loading XS

use vars qw{$VERSION @ISA};
my @tag_hist;

BEGIN
{
    $VERSION  = '0.400';
    @tag_hist = qw(alias sno tassilo modern);
}

use Sub::Exporter '-setup' => {
    exports => [
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
        ( map { $_ => \&_build_imp } qw(any all none notall firstval sort_by nsort_by) ),
        # those are just aliases
        (
           map { $_ => \&_build_imp }
             qw(first_index last_index first_value last_value zip distinct)
        ),
    ],
    groups => { map { $_ => \&_build_lmu_group } @tag_hist }
                           };

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
                functions => { map { $_ => 1 } qw(any all none notall firstval) },
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

my %impl_by_caller;

my $default_imp = "alias";

sub _build_imp
{
    my ( $class, $name, $arg ) = @_;
    my $i = 0;
    my @caller;
    do
    {
        @caller = caller( $i++ );
    } while ( $caller[0] eq "Sub::Exporter" );

    my @impls = ( "HASH" eq ref $arg and $arg->{impl} ) ? $arg->{impl} : @tag_hist;
    defined $alias_list{$name} and $name = $alias_list{$name};
    use DDP;
    p(@impls);

    foreach my $impl (@impls)
    {
        my $exp_sub;
        defined $pkg_tags{$impl}->{functions}->{$name}
          and use_module( $pkg_tags{$impl}->{module} )
          and $exp_sub = $pkg_tags{$impl}->{module}->can($name);

        my $nm = defined $arg->{as} ? $arg->{as} : $name;
        # $exp_sub and $impl_by_caller{$caller[0]}->{$name}->{$nm} = $impl and return $exp_sub;
        $exp_sub and $impl_by_caller{ $caller[0] }->{$name}->{$nm} = $impl;
        #use DDP;
        #p(%impl_by_caller);
        $exp_sub and return $exp_sub;
    }

    return;
}

sub _build_lmu_group
{
    my ( $class, $group, $arg ) = @_;
    my $i = 0;
    my @caller;
    do
    {
        @caller = caller( $i++ );
    } while ( $caller[0] eq "Sub::Exporter" );

    my @impls = "ARRAY" eq ref $group ? @$group : ($group);

    my %exp_subs;
    foreach my $impl (@impls)
    {
        print( STDERR "<--\n" );
        foreach my $func ( keys %{ $pkg_tags{$impl}->{functions} } )
        {
            defined $exp_subs{$func} and next;
            defined $impl_by_caller{ $caller[0] }->{$func}->{$func} and next;

            use_module( $pkg_tags{$impl}->{module} );
            $exp_subs{$func} = $pkg_tags{$impl}->{module}->can($func);
            defined $alias_list{$func} and $exp_subs{ $alias_list{$func} } = $exp_subs{$func};

            $impl_by_caller{ $caller[0] }->{$func}->{$func} = $impl;
        }
    }

    return \%exp_subs;
}

1;
