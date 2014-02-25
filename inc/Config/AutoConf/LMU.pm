package Config::AutoConf::LMU;

use strict;
use warnings;

use parent qw(Config::AutoConf);

sub new
{
    my ( $class, %args ) = @_;
    my $self = $class->SUPER::new(%args);
    # XXX might add c++ if required for some operating systems
    return $self;
}

sub _default_headers_with_perl
{
    my ($self) = @_;

    my $include_perl = "#include <EXTERN.h>\n#include <perl.h>";
    my $includes = join( "\n", $self->_default_includes, $include_perl );

    return $includes;
}

sub _set_argv
{
    my ( $self, @argv ) = @_;
    $self = $self->_get_instance;
    $self->{_argv} = \@argv;
    return;
}

sub check_sane_xs
{
    my ($self) = @_;

    my $includes = $self->_default_headers_with_perl();
    my $conftest = $self->lang_build_program( $includes, "" );

    my $sanexs = $self->compile_if_else($conftest);

    return $sanexs;
}

sub with_xs
{
    my $self       = shift->_get_instance;
    my $cache_name = $self->_cache_name(qw(config with xs));
    return $self->check_cached(
        $cache_name,
        "whether enable xs or not",
        sub {
            foreach ( @{ $self->{_argv} } )
            {
                /^-pm/ and return 0;
                /^-xs/ and return 1;
            }

            return $self->check_sane_xs();
        }
    );
}

1;
