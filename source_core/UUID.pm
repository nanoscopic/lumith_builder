# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub new_id {
    my $ug = Data::UUID->new();
    return lc( $ug->create_str() );
}
