package Config::AutoConf::LMU;

use strict;
use warnings;

use Config::AutoConf '0.28';

use parent qw(Config::AutoConf);

sub _check_pureperl_build_wanted
{
    my $self = shift->_get_instance;
    foreach ( @{ $self->{_argv} } )
    {
	/^-pm/ and warn "-pm is depreciated, please use PUREPERL_ONLY=1" and return 0;
	/^-xs/ and warn "-xs is depreciated, building XS is default anyway" and return $self->{_force_xs} = 1;
    }
    return $self->SUPER::_check_pureperl_build_wanted(@_);
}

sub check_sane_xs
{
    my $self = shift->_get_instance;
    my $xs = $self->SUPER::check_sane_xs(@_);
    $self->{_force_xs} and !$xs and $self->msg_error("XS forced but can't compile - giving up");
    return $xs;
}

1;
