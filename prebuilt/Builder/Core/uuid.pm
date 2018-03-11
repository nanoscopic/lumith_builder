package Builder::Core::uuid;
use Data::UUID ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::uuid::init ) && !$self->{'skipInit'} );
                return $self;
            }sub new_id { #@5
    my $self=shift;
  my %_params = @_;
    my $ug = Data::UUID->new();#@6
    return lc( $ug->create_str() );#@7
}

1;
