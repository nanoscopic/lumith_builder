package Melon::Builder::systemx;
use strict;
use warnings;#@1

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                
                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::systemx::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
$self->{build_id} = '0855009e-b8e4-11e7-bbb3-89d00a5e369c';
    $self->{name} = 'MelonBuilder';
    $self->{pkg} = 'Melon::Builder::';
    $self->{g}={};
require Melon::Builder::tagactions;
require Melon::Builder::cmdline;
require Melon::Builder::tagsystem;
require Melon::Builder::builder;
require Melon::Builder::subwriter;
require Melon::Builder::versiontracker;
require Melon::Builder::systemgen;
require Melon::Builder::taghandlers;
    my $mods = $self->{'mods'} = {};
my $systems = $self->{'systems'} = {};
my $importedModules = $self->{'importedModules'} = {};

                        my $core2_log_conf = {};
                        if( $_params{'conf_log'} ) {
                            $core2_log_conf = $_params{'conf_log'};
                        }
                        my $core2_xml_conf = {};
                        if( $_params{'conf_xml'} ) {
                            $core2_xml_conf = $_params{'conf_xml'};
                        }
                        my $core2_templates_conf = {};
                        if( $_params{'conf_templates'} ) {
                            $core2_templates_conf = $_params{'conf_templates'};
                        }
                        my $core2_uuid_conf = {};
                        if( $_params{'conf_uuid'} ) {
                            $core2_uuid_conf = $_params{'conf_uuid'};
                        }
                #my $core2modules = $systems->{'core2'} = {};
                {
                    no warnings 'redefine';
                    require Builder::Core2::systemx;
                }
                my $system_core2 = $systems->{'core2'} = "Builder::Core2::systemx"->new(
                    tagsystem => $_params{'tagsystem'},
                    lang => ( $_params{'lang'} || 'perl' ),
                    
                );$importedModules->{'log'} = $system_core2->getmod('log');
$mods->{'log'} = $system_core2->getmod('log');
$importedModules->{'xml'} = $system_core2->getmod('xml');
$mods->{'xml'} = $system_core2->getmod('xml');
$importedModules->{'templates'} = $system_core2->getmod('templates');
$mods->{'templates'} = $system_core2->getmod('templates');
$importedModules->{'uuid'} = $system_core2->getmod('uuid');
$mods->{'uuid'} = $system_core2->getmod('uuid');
  # round 1

            my $conf_cmdline;
            my $confX_cmdline = {};
            # Imported conf comes through params
            if( $_params{'conf_cmdline'} ) {
                $confX_cmdline = $_params{'conf_cmdline'};
            }    $mods->{'cmdline'} = Melon::Builder::cmdline->new( sys => $self, conf => $confX_cmdline,
  );

            my $conf_tagsystem;
            my $confX_tagsystem = {};
            # Imported conf comes through params
            if( $_params{'conf_tagsystem'} ) {
                $confX_tagsystem = $_params{'conf_tagsystem'};
            }    $mods->{'tagsystem'} = Melon::Builder::tagsystem->new( sys => $self, conf => $confX_tagsystem,
  );

            my $conf_builder;
            my $confX_builder = {};
            # Imported conf comes through params
            if( $_params{'conf_builder'} ) {
                $confX_builder = $_params{'conf_builder'};
            }    $mods->{'builder'} = Melon::Builder::builder->new( sys => $self, conf => $confX_builder,
  );

            my $conf_subwriter;
            my $confX_subwriter = {};
            # Imported conf comes through params
            if( $_params{'conf_subwriter'} ) {
                $confX_subwriter = $_params{'conf_subwriter'};
            }    $mods->{'subwriter'} = Melon::Builder::subwriter->new( sys => $self, conf => $confX_subwriter,
    mod_log => $importedModules->{'log'},
  );

            my $conf_versiontracker;
            my $confX_versiontracker = {};
            # Imported conf comes through params
            if( $_params{'conf_versiontracker'} ) {
                $confX_versiontracker = $_params{'conf_versiontracker'};
            }    $mods->{'versiontracker'} = Melon::Builder::versiontracker->new( sys => $self, conf => $confX_versiontracker,
  );

            my $conf_systemgen;
            my $confX_systemgen = {};
            # Imported conf comes through params
            if( $_params{'conf_systemgen'} ) {
                $confX_systemgen = $_params{'conf_systemgen'};
            }    $mods->{'systemgen'} = Melon::Builder::systemgen->new( sys => $self, conf => $confX_systemgen,
    mod_uuid => $importedModules->{'uuid'},
    mod_templates => $importedModules->{'templates'},
  );
    $mods->{'systemx'} = $self;

            my $conf_taghandlers;
            my $confX_taghandlers = {};
            # Imported conf comes through params
            if( $_params{'conf_taghandlers'} ) {
                $confX_taghandlers = $_params{'conf_taghandlers'};
            }    $mods->{'taghandlers'} = Melon::Builder::taghandlers->new( sys => $self, conf => $confX_taghandlers,
    mod_templates => $importedModules->{'templates'},
  );
  # round 2

            my $conf_tagactions;
            my $confX_tagactions = {};
            # Imported conf comes through params
            if( $_params{'conf_tagactions'} ) {
                $confX_tagactions = $_params{'conf_tagactions'};
            }    $mods->{'tagactions'} = Melon::Builder::tagactions->new( sys => $self, conf => $confX_tagactions,
    mod_builder => $mods->{'builder'},
  );
    $mods->{'tagsystem'}{'mod_builder'} = $mods->{'builder'};
    $mods->{'builder'}{'mod_taghandlers'} = $mods->{'taghandlers'};
    $mods->{'builder'}{'mod_tagsystem'} = $mods->{'tagsystem'};
    $mods->{'builder'}{'mod_subwriter'} = $mods->{'subwriter'};
    $mods->{'builder'}{'mod_versiontracker'} = $mods->{'versiontracker'};
    $mods->{'builder'}{'mod_systemgen'} = $mods->{'systemgen'};
    $mods->{'subwriter'}{'mod_builder'} = $mods->{'builder'};
    $mods->{'systemgen'}{'mod_tagsystem'} = $mods->{'tagsystem'};
    $mods->{'systemgen'}{'mod_builder'} = $mods->{'builder'};
    $mods->{'taghandlers'}{'mod_systemgen'} = $mods->{'systemgen'};
    $mods->{'taghandlers'}{'mod_router'} = $mods->{'router'};
    $mods->{'taghandlers'}{'mod_builder'} = $mods->{'builder'};
    my $tagsystem = $_params{'tagsystem'};
    if( $tagsystem ) {
      my $lang = $_params{'lang'} || 'perl';
$mods->{'xml'}->setup_tags( $tagsystem, lang => $lang ) if( $mods->{'xml'} );
    }

    if( $mods->{'conf'} ) {
        $mods->{'conf'}->doConf(
            modInstances => $mods,
            mods => [ 'tagactions','cmdline','tagsystem','builder','subwriter','versiontracker','systemgen','systemx','taghandlers' ],
            conf => {
                tagactions => $confX_tagactions,
cmdline => $confX_cmdline,
tagsystem => $confX_tagsystem,
builder => $confX_builder,
subwriter => $confX_subwriter,
versiontracker => $confX_versiontracker,
systemgen => $confX_systemgen,
taghandlers => $confX_taghandlers
            },
            hasConf => {
                tagactions => (defined( &Melon::Builder::::tagactions::conf )?1:0),
cmdline => (defined( &Melon::Builder::::cmdline::conf )?1:0),
tagsystem => (defined( &Melon::Builder::::tagsystem::conf )?1:0),
builder => (defined( &Melon::Builder::::builder::conf )?1:0),
subwriter => (defined( &Melon::Builder::::subwriter::conf )?1:0),
versiontracker => (defined( &Melon::Builder::::versiontracker::conf )?1:0),
systemgen => (defined( &Melon::Builder::::systemgen::conf )?1:0),
taghandlers => (defined( &Melon::Builder::::taghandlers::conf )?1:0)
            }
        );
    }
    else {
  if( defined( &Melon::Builder::::tagactions::conf ) ) { $mods->{'tagactions'}->conf( $confX_tagactions );
 }
  if( defined( &Melon::Builder::::cmdline::conf ) ) { $mods->{'cmdline'}->conf( $confX_cmdline );
 }
  if( defined( &Melon::Builder::::tagsystem::conf ) ) { $mods->{'tagsystem'}->conf( $confX_tagsystem );
 }
  if( defined( &Melon::Builder::::builder::conf ) ) { $mods->{'builder'}->conf( $confX_builder );
 }
  if( defined( &Melon::Builder::::subwriter::conf ) ) { $mods->{'subwriter'}->conf( $confX_subwriter );
 }
  if( defined( &Melon::Builder::::versiontracker::conf ) ) { $mods->{'versiontracker'}->conf( $confX_versiontracker );
 }
  if( defined( &Melon::Builder::::systemgen::conf ) ) { $mods->{'systemgen'}->conf( $confX_systemgen );
 }
  if( defined( &Melon::Builder::::taghandlers::conf ) ) { $mods->{'taghandlers'}->conf( $confX_taghandlers );
 }
}
if( defined( &Melon::Builder::::tagactions::postconf ) ) { $mods->{'tagactions'}->postconf();
 }
if( defined( &Melon::Builder::::cmdline::postconf ) ) { $mods->{'cmdline'}->postconf();
 }
if( defined( &Melon::Builder::::tagsystem::postconf ) ) { $mods->{'tagsystem'}->postconf();
 }
if( defined( &Melon::Builder::::builder::postconf ) ) { $mods->{'builder'}->postconf();
 }
if( defined( &Melon::Builder::::subwriter::postconf ) ) { $mods->{'subwriter'}->postconf();
 }
if( defined( &Melon::Builder::::versiontracker::postconf ) ) { $mods->{'versiontracker'}->postconf();
 }
if( defined( &Melon::Builder::::systemgen::postconf ) ) { $mods->{'systemgen'}->postconf();
 }
if( defined( &Melon::Builder::::taghandlers::postconf ) ) { $mods->{'taghandlers'}->postconf();
 }
}
sub getmod { #@9
    my $self=shift;
    my $modname = shift;
  my %_params = @_;
    return $self->{'mods'}{$modname};#@10
}

1;
