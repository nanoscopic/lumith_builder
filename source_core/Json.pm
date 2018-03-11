# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

use JSON::XS;
sub init {
    $self->{'encoder'} = JSON::XS->new->pretty;
}

sub encode( ob ) {
    return $self->{'encoder'}->encode( $ob );
}

sub decode( ob ) {
    return $self->{'encoder'}->decode( $ob );
}