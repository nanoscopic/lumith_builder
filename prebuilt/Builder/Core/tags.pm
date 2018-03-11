package Builder::Core::tags;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::tags::init ) && !$self->{'skipInit'} );
                return $self;
            }sub tag_x { #@5
    my $self=shift;
  my %_params = @_;
    return "#test of x tag\n";#@7
}
sub setup_tags { #@?
    my $self=shift;
    my $tagsystem = shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@?
                print 'Setting up tags from module '.__FILE__."\n";#@?
                $self->{'lang'} = $lang || 'perl';#@?
            $tagsystem->register_tag(
                name => 'x',
                func => \&tag_x,
                mod => $self,
                stage => 'normal',
                type => 'normal'
            );#@?
}

1;
