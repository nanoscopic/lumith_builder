package Builder::Core::api;
use JSON::XS ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::api::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
    $self->{'apis'} = {};#@6
    $self->{'coder'} = JSON::XS->new();#@7
}
sub tag_api { #@11
    my $self=shift;
  my %_params = @_;
    my $mod_request = $self->{'mod_request'};
    my $mod_api = $self->{'mod_api'};
    my $tag = $_params{'metacode'};#@13
    my $apiName = $tag->{'name'};#@14
    my $defaultOp = $tag->{'defaultOp'} || 0;#@15
    my $actions = [
        {
            action => 'add_text',
            text => "    <page name='$apiName' />\
    my \$params = \$mod_request->{'params'};\
    \$mod_api->handle_api_call( \$self->{'mod_response'}, '$apiName', \$params );\
        "
        },
        {
            action => 'add_mod',
            mod => 'response',
            delayed => 1,
            var => 'mod_response'
        }
    ];#@31
    if( $defaultOp ) {
        push( @$actions, { action => 'add_sub_text', sub => 'init', text => "
            \$mod_api->init_api( '$apiName', '$defaultOp' );\
        " } );#@35
    }
    return $actions;#@37
}
sub init_api { #@40
    my $self=shift;
    my $apiName = shift;
    my $defaultOp = shift;
  my %_params = @_;
    $self->{'apis'}{ $apiName } ||= {};#@41
    my $opHash = $self->{'apis'}{$apiName};#@42
    $opHash->{'defaultOp'} = $defaultOp;#@43
}
sub handle_api_call { #@46
    my $self=shift;
    my $resp = shift;
    my $apiName = shift;
    my $params = shift;
  my %_params = @_;
    my $opHash = $self->{'apis'}{$apiName};#@47
    my $json = $params->{'json'};#@49
    my $data;#@50
    my $opName;#@51
    if( $json && $json ne '{}' ) {
        $data = $self->{'coder'}->decode( $json );#@53
        $opName = $data->{'op'} || 0;# or die "No op specified in json parameters";#@54
    }
    else {
        $data = $params;#@57
        $opName = $data->{'op'} || 0;#@58
    }
    if( !$opName ) {
        $opName = $opHash->{'defaultOp'};#@61
    }
    if( !$opName ) {
        $resp->output("Opname not specified");#@64
        return;#@65
    }
    my $op = $opHash->{ $opName } or die "Op named $opName not found in $apiName api";#@67
    my $sub = $op->{'sub'};#@68
    my $resp_json = $sub->( $op->{'obj'}, $data );#@69
    $resp->set_response_type('json');#@70
    $resp->output( $resp_json );#@71
}
sub register_api_op { #@74
    my $self=shift;
    my $apiName = shift;
    my $opName = shift;
    my $callback = shift;
    my $obj = shift;
  my %_params = @_;
    my $apis = $self->{'apis'};#@77
    $apis->{ $apiName } ||= {};#@78
    my $api = $apis->{ $apiName };#@79
    $api->{ $opName } = { sub => $callback, obj => $obj };#@81
}
sub tag_api_op { #@85
    my $self=shift;
  my %_params = @_;
    my $tag = $_params{'metacode'};#@88
    my $builder = $_params{'builder'};#@89
    my $api = $tag->{'api'};#@91
    my $opName = $tag->{'op'};#@92
    my $subName = $builder->{'cursub'}{'name'};#@93
    return [
        { action => 'add_sub_text', sub => 'init', text => "\
            \$"."mod_api->register_api_op( '$api', '$opName', \\&$subName, \$self );\
        " }
    ];        
}
sub setup_tags { #@?
    my $self=shift;
    my $tagsystem = shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@?
                print 'Setting up tags from module '.__FILE__."\n";#@?
                $self->{'lang'} = $lang || 'perl';#@?
            $tagsystem->register_tag(
                name => 'api',
                func => \&tag_api,
                mod => $self,
                stage => 'normal',
                type => 'normal'
            );#@?
            $tagsystem->register_tag(
                name => 'api_op',
                func => \&tag_api_op,
                mod => $self,
                stage => 'normal',
                type => 'normal'
            );#@?
}

1;
