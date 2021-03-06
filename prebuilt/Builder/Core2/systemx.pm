package Builder::Core2::systemx;
use strict;
use warnings;#@1

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                
                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core2::systemx::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
$self->{build_id} = '0840933e-b8e4-11e7-bbb3-89d00a5e369c';
    $self->{name} = 'BCore2';
    $self->{pkg} = 'Builder::Core2::';
    $self->{g}={};
require Builder::Core2::xml;
    my $mods = $self->{'mods'} = {};
my $systems = $self->{'systems'} = {};
my $importedModules = $self->{'importedModules'} = {};

                        my $core_api_conf = {};
                        if( $_params{'conf_api'} ) {
                            $core_api_conf = $_params{'conf_api'};
                        }
                        my $core_log_conf = {};
                        if( $_params{'conf_log'} ) {
                            $core_log_conf = $_params{'conf_log'};
                        }
                        my $core_templates_conf = {};
                        if( $_params{'conf_templates'} ) {
                            $core_templates_conf = $_params{'conf_templates'};
                        }
                        my $core_uuid_conf = {};
                        if( $_params{'conf_uuid'} ) {
                            $core_uuid_conf = $_params{'conf_uuid'};
                        }
                #my $coremodules = $systems->{'core'} = {};
                {
                    no warnings 'redefine';
                    require Builder::Core::systemx;
                }
                my $system_core = $systems->{'core'} = "Builder::Core::systemx"->new(
                    tagsystem => $_params{'tagsystem'},
                    lang => ( $_params{'lang'} || 'perl' ),
                    
                );$importedModules->{'api'} = $system_core->getmod('api');
$mods->{'api'} = $system_core->getmod('api');
$importedModules->{'log'} = $system_core->getmod('log');
$mods->{'log'} = $system_core->getmod('log');
$importedModules->{'templates'} = $system_core->getmod('templates');
$mods->{'templates'} = $system_core->getmod('templates');
$importedModules->{'uuid'} = $system_core->getmod('uuid');
$mods->{'uuid'} = $system_core->getmod('uuid');
  # round 1

            my $conf_xml;
            my $confX_xml = {};
            # Imported conf comes through params
            if( $_params{'conf_xml'} ) {
                $confX_xml = $_params{'conf_xml'};
            }    $mods->{'xml'} = Builder::Core2::xml->new( sys => $self, conf => $confX_xml,
    mod_templates => $importedModules->{'templates'},
  );
    $mods->{'systemx'} = $self;
 
    $mods->{'xml'}{'mod_xml_'} = $mods->{'xml_'};
    
    my $tagsystem = $_params{'tagsystem'};
    if( $tagsystem ) {
      my $lang = $_params{'lang'} || 'perl';
$mods->{'tags'}->setup_tags( $tagsystem, lang => $lang ) if( $mods->{'tags'} );
$mods->{'api'}->setup_tags( $tagsystem, lang => $lang ) if( $mods->{'api'} );
$mods->{'templates'}->setup_tags( $tagsystem, lang => $lang ) if( $mods->{'templates'} );
$mods->{'log'}->setup_tags( $tagsystem, lang => $lang ) if( $mods->{'log'} );
    }

    if( $mods->{'conf'} ) {
        $mods->{'conf'}->doConf(
            modInstances => $mods,
            mods => [ 'xml','systemx' ],
            conf => {
                xml => $confX_xml
            },
            hasConf => {
                xml => (defined( &Builder::Core2::::xml::conf )?1:0)
            }
        );
    }
    else {
  if( defined( &Builder::Core2::::xml::conf ) ) { $mods->{'xml'}->conf( $confX_xml );
 }
}
if( defined( &Builder::Core2::::xml::postconf ) ) { $mods->{'xml'}->postconf();
 }
}
sub getmod { #@9
    my $self=shift;
    my $modname = shift;
  my %_params = @_;
    return $self->{'mods'}{$modname};#@10
}

1;
