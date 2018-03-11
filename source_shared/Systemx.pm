# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init {
    <sysblock/>
}

sub getmod( modname ) {
    return $self->{'mods'}{$modname};
}