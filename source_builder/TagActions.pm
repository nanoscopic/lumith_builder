# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init {
    my $b = $mod_builder;
    $b->register_action( "add_mod"          , \&action_add_mod      , $self );
    $b->register_action( "add_var"          , \&action_add_var      , $self );
    $b->register_action( "add_sub_var"      , \&action_add_sub_var  , $self );
    $b->register_action( "add_sub_text"     , \&action_add_sub_text , $self );
    $b->register_action( "add_text"         , \&action_add_text     , $self );
    $b->register_action( "add_sub"          , \&action_add_sub      , $self );
    $b->register_action( "create_module"    , \&action_create_module, $self );
}

sub action_add_mod( actionNode, taghash, cursub, subhash ) {
    my $construct = $taghash->{'construct'} ||= {};
    my $modules = $construct->{'modules'} ||= {};
    my $new_module = $actionNode->{'mod'};
    $modules->{ $new_module } = {
        delayed => ( $actionNode->{'delayed'} || 0 ),
        var => ( $actionNode->{'var'} || '' )
    };
    0;
}

sub action_add_var( actionNode, taghash, cursub, subhash ) {
    my $vars = $cursub->{'vars'};
    my $as = $actionNode->{'var'} || '';
    push( @$vars, { self => $actionNode->{'self'}, var => $as } );
    0;
}

sub action_add_sub_var( actionNode, taghash, cursub, subhash ) {
    my $subNameToAddTo = $actionNode->{'sub'};
    my $subToAddTo = $subhash->{$subNameToAddTo};
    my $vars = $subToAddTo->{'vars'};
    my $as = $actionNode->{'var'} || '';
    push( @$vars, { self => $actionNode->{'self'}, var => $as } );
    0;
}

sub action_add_sub_text( actionNode, taghash, cursub, subhash ) {
    <param name="module" />
    <param name="modinfo" />
    my $subNameToAddTo = $actionNode->{'sub'};
    my @lines = split(/\n/, $actionNode->{'text'});
    my $newParts = $mod_builder->split_lines_to_parts( \@lines );
    $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );
    
    my $subToAddTo = $subhash->{$subNameToAddTo};
    my $subparts = $subToAddTo->{'parts'};
    cut_ending_paran( $subparts );
    push( @$subparts, @$newParts, { type => 'line', text => "}\n" } );
    0;
}

sub action_add_text( actionNode, taghash, cursub, subhash ) {
    <param name="module" />
    <param name="modinfo" />
    my @lines = split(/\n/, $actionNode->{'text'});
    my $newParts = $mod_builder->split_lines_to_parts( \@lines );
    $mod_builder->parse_xml_parts( $newParts );
    $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );
    #print "New parts: ".Dumper( $newParts );
    my $moreXml = $mod_builder->parse_xml_parts( $newParts );
    if( $moreXml ) {
        $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );
    }
    #print "After xml parse: ".Dumper( $newParts );
    return $newParts;
}

sub action_add_sub( actionNode, taghash, cursub, subhash ) {
    my $subToAdd = $actionNode->{'name'};
    if( !$subhash->{ $subToAdd } ) {
        #print "  Adding sub named $subToAdd\n";
        my $text = $actionNode->{'text'};
        if( !$text ) {
            $text = "sub $subToAdd {\n}\n";
        }
        my @lines = split(/\n/, $text);
        my $newParts = $mod_builder->split_lines_to_parts( \@lines );
        $mod_builder->parse_xml_parts( $newParts );
        my $newSubs = $mod_builder->split_parts_to_subs( $newParts );
        my $subs = $mod_builder->{'subs'};
        shift @$newSubs; # delete the 'init' sub
        push( @$subs, @$newSubs );
    }
    else {
        #print "  Skipping sub named $subToAdd\n";
    }
    0;
}

sub action_create_module( actionNode, taghash, cursub, subhash ) {
    my $module_build_result = $mod_builder->{'module_build_result'};
    my $new_modules = $module_build_result->{'new_modules'} ||= [];
    
    my $newFile = $actionNode->{'file'};
    
    my @parts = split( "/", $newFile );
    my $fileName = pop( @parts );
    my $path = ".";
    for my $part ( @parts ) {
        $path .= "/$part";
        if( ! -e $path ) {
            mkdir $path;
        }
    }
    
    my $text = $actionNode->{'text'};
    write_file( $newFile, $text );
    
    my $newConf = {
        name => $actionNode->{'name'},
        file => $newFile,
        generated => 1
    };
    if( $actionNode->{'multiple'} ) {
        $newConf->{'multiple'} = 1;
    }
    push( @$new_modules, $newConf );
    0;
}

psub cut_ending_paran {
    my $parts = shift;
    my $i = 0;
    my $ok = 0;
    return if( !$parts );
    for( $i=((scalar @$parts)-1); $i >= 0; $i-- ) {
        my $part = $parts->[ $i ];
        my $type = $part->{'type'};
        if( $type eq 'line' ) {
            my $text = $part->{'text'};
            if( $text =~ m/^\s*\}\s*$/ ) {
                $ok = 1;
                last;
            }
        }
    }
    die if( !$ok );
    delete $parts->[ $i ];
}