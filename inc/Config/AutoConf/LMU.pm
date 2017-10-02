package inc::Config::AutoConf::LMU;

use strict;
use warnings;

use Config::AutoConf '0.315';

use base qw(Config::AutoConf);

sub _check_pureperl_required
{
    my $self = shift->_get_instance;
    foreach (@{$self->{_argv}})
    {
        /^-pm/ and warn "-pm is depreciated, please use PUREPERL_ONLY=1" and return 1;
        /^-xs/ and warn "-xs is depreciated, building XS is default anyway" and return !($self->{_force_xs} = 1);
    }
    return $self->SUPER::_check_pureperl_required(@_);
}

sub check_produce_xs_build
{
    my $self = shift->_get_instance;
    my $xs   = $self->SUPER::check_produce_xs_build(@_);
    $self->{_force_xs} and !$xs and $self->msg_error("XS forced but can't compile - giving up");
    return $xs;
}

1;
