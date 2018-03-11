package Melon::Builder::junk;
use strict;
use warnings;#@1
my $SYS;
sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless {}, $class;
$SYS = $params{'sys'};
    $self->init(%params) if( defined( &Melon::Builder::junk::init ) && !$self->{'skipInit'} );
    return $self;
}
sub test {
    my $self=shift;
  my %_params = @_;
}

1;
