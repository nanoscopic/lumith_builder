package Builder::Core::systemx;
use strict;
use warnings;#@1

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                
                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::systemx::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
$self->{build_id} = '081c722e-b8e4-11e7-bbb3-89d00a5e369c';
    $self->{name} = 'BCore';
    $self->{pkg} = 'Builder::Core::';
    $self->{g}={};
require Builder::Core::tags;
require Builder::Core::log;
require Builder::Core::conf;
require Builder::Core::templates;
require Builder::Core::api;
require Builder::Core::uuid;
    my $mods = $self->{'mods'} = {};
  # round 1

            my $conf_tags;
            my $confX_tags = {};
            # Imported conf comes through params
            if( $_params{'conf_tags'} ) {
                $confX_tags = $_params{'conf_tags'};
            }    $mods->{'tags'} = Builder::Core::tags->new( sys => $self, conf => $confX_tags,
  );
    $mods->{'systemx'} = $self;

            my $conf_log;
            my $confX_log = {};
            # Imported conf comes through params
            if( $_params{'conf_log'} ) {
                $confX_log = $_params{'conf_log'};
            }
                if( ref( $confX_log ) ne 'ARRAY' ) { $confX_log = [ $confX_log ]; }
                my $conf_xml_log =<<'ENDEND';
<logfile>/home/user/lumith_builder/log/log.xml</logfile>
ENDEND
                my ( $ob_log, $newConfX_log ) = XML::Bare->simple( text => $conf_xml_log );
                push( @{$confX_log}, $newConfX_log );    $mods->{'log'} = Builder::Core::log->new( sys => $self, conf => $confX_log,
  );

            my $conf_conf;
            my $confX_conf = {};
            # Imported conf comes through params
            if( $_params{'conf_conf'} ) {
                $confX_conf = $_params{'conf_conf'};
            }    $mods->{'conf'} = Builder::Core::conf->new( sys => $self, conf => $confX_conf,
  );

            my $conf_templates;
            my $confX_templates = {};
            # Imported conf comes through params
            if( $_params{'conf_templates'} ) {
                $confX_templates = $_params{'conf_templates'};
            }    $mods->{'templates'} = Builder::Core::templates->new( sys => $self, conf => $confX_templates,
  );

            my $conf_api;
            my $confX_api = {};
            # Imported conf comes through params
            if( $_params{'conf_api'} ) {
                $confX_api = $_params{'conf_api'};
            }    $mods->{'api'} = Builder::Core::api->new( sys => $self, conf => $confX_api,
  );

            my $conf_uuid;
            my $confX_uuid = {};
            # Imported conf comes through params
            if( $_params{'conf_uuid'} ) {
                $confX_uuid = $_params{'conf_uuid'};
            }    $mods->{'uuid'} = Builder::Core::uuid->new( sys => $self, conf => $confX_uuid,
  );
    $mods->{'log'}{'mod_log'} = $mods->{'log'};
    $mods->{'templates'}{'mod_urls'} = $mods->{'urls'};
    $mods->{'templates'}{'mod_templates'} = $mods->{'templates'};
    $mods->{'api'}{'mod_request'} = $mods->{'request'};
    $mods->{'api'}{'mod_api'} = $mods->{'api'};

    if( $mods->{'conf'} ) {
        $mods->{'conf'}->doConf(
            modInstances => $mods,
            mods => [ 'tags','systemx','log','conf','templates','api','uuid' ],
            conf => {
                tags => $confX_tags,
log => $confX_log,
conf => $confX_conf,
templates => $confX_templates,
api => $confX_api,
uuid => $confX_uuid
            },
            hasConf => {
                tags => (defined( &Builder::Core::::tags::conf )?1:0),
log => (defined( &Builder::Core::::log::conf )?1:0),
conf => (defined( &Builder::Core::::conf::conf )?1:0),
templates => (defined( &Builder::Core::::templates::conf )?1:0),
api => (defined( &Builder::Core::::api::conf )?1:0),
uuid => (defined( &Builder::Core::::uuid::conf )?1:0)
            }
        );
    }
    else {
  if( defined( &Builder::Core::::tags::conf ) ) { $mods->{'tags'}->conf( $confX_tags );
 }
  if( defined( &Builder::Core::::log::conf ) ) { $mods->{'log'}->conf( $confX_log );
 }
  if( defined( &Builder::Core::::conf::conf ) ) { $mods->{'conf'}->conf( $confX_conf );
 }
  if( defined( &Builder::Core::::templates::conf ) ) { $mods->{'templates'}->conf( $confX_templates );
 }
  if( defined( &Builder::Core::::api::conf ) ) { $mods->{'api'}->conf( $confX_api );
 }
  if( defined( &Builder::Core::::uuid::conf ) ) { $mods->{'uuid'}->conf( $confX_uuid );
 }
}
if( defined( &Builder::Core::::tags::postconf ) ) { $mods->{'tags'}->postconf();
 }
if( defined( &Builder::Core::::log::postconf ) ) { $mods->{'log'}->postconf();
 }
if( defined( &Builder::Core::::conf::postconf ) ) { $mods->{'conf'}->postconf();
 }
if( defined( &Builder::Core::::templates::postconf ) ) { $mods->{'templates'}->postconf();
 }
if( defined( &Builder::Core::::api::postconf ) ) { $mods->{'api'}->postconf();
 }
if( defined( &Builder::Core::::uuid::postconf ) ) { $mods->{'uuid'}->postconf();
 }
}
sub getmod { #@9
    my $self=shift;
    my $modname = shift;
  my %_params = @_;
    return $self->{'mods'}{$modname};#@10
}

1;
