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

sub check_sane_xs
{
    my ( $self ) = @_;

    my $includes    = $self->_default_headers_with_perl();
    my $conftest    = $self->lang_build_program( $includes, "" );

    my $sanexs = $self->compile_if_else($conftest);

    return $sanexs;
}

1;
