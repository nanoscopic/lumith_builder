# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init {
    $self->{'apis'} = {};
    $self->{'coder'} = JSON::XS->new();
}

# An API is an entry point/page to call various operations
sub tag_api {
    <tag name="api" />
    <param name="metacode" var="tag" />
    my $apiName = $tag->{'name'};
    my $defaultOp = $tag->{'defaultOp'} || 0;
    
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
    ];
    if( $defaultOp ) {
        push( @$actions, { action => 'add_sub_text', sub => 'init', text => "
            \$mod_api->init_api( '$apiName', '$defaultOp' );\
        " } );
    }
    return $actions;
}

sub init_api( apiName, defaultOp ) {
    $self->{'apis'}{ $apiName } ||= {};
    my $opHash = $self->{'apis'}{$apiName};
    $opHash->{'defaultOp'} = $defaultOp;
}

sub handle_api_call( resp, apiName, params ) {
    my $opHash = $self->{'apis'}{$apiName};
    
    my $json = $params->{'json'};
    my $data;
    my $opName;
    if( $json && $json ne '{}' ) {
        $data = $self->{'coder'}->decode( $json );
        $opName = $data->{'op'} || $params->{'op'};# or die "No op specified in json parameters";
    }
    else {
        $data = $params;
        $opName = $data->{'op'} || 0;
    }
    if( !$opName ) {
        $opName = $opHash->{'defaultOp'};
    }
    if( !$opName ) {
        $resp->output("Opname not specified");
        return;
    }
    my $op = $opHash->{ $opName } or die "Op named $opName not found in $apiName api";
    my $sub = $op->{'sub'};
    my $resp_json = $sub->( $op->{'obj'}, $data );
    $resp->set_response_type('json');
    $resp->output( $resp_json );
}

sub register_api_op( apiName, opName, callback, obj ) {
    #$self->{'apis'}{ $apiName } ||= {};
    
    my $apis = $self->{'apis'};
    $apis->{ $apiName } ||= {};
    my $api = $apis->{ $apiName };
    
    $api->{ $opName } = { sub => $callback, obj => $obj };
}

# An operation is a single callable subroutine in an API
sub tag_api_op {
    <tag name="api_op" />
    
    <param name="metacode" var="tag" />
    <param name="builder" />
    
    my $api = $tag->{'api'};
    my $opName = $tag->{'op'};
    my $subName = $builder->{'cursub'}{'name'};
    
    return [
        { action => 'add_sub_text', sub => 'init', text => "\
            \$"."mod_api->register_api_op( '$api', '$opName', \\&$subName, \$self );\
        " }
    ];        
}