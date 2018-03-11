# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub register_tag {
    <param name="name" var="tagname" />
    <param name="func" />
    <param name="mod" />
    <param name="stage" var="stageName" />
    <param name="type" />
    <param name="alias" var="aliasP" />

    $type ||= 'normal';
    $aliasP ||= 0; # this is probably not needed...
    
    #print "Register tag: ".Dumper( \%parm );
    
    if( !$stageName ) {
        die "Stage must be specified when registering a tag";
    }
    my $stageHash = $mod_builder->{'stage_hash'};
    my $stage = $stageHash->{ $stageName } or die "Could not find stage $stageName";
    
    my $tags = $stage->{'tags'};
    
    my $callback_info = { func => $func, mod => $mod };
    $tags->{ $tagname } = $callback_info;
    if( $aliasP ) {
        my $aliasA = forcearray( $aliasP );
        for my $alias ( @$aliasA ) {
            $tags->{ $alias } = $callback_info;
            if( $type eq 'raw' ) {
                #print "Making $alias raw\n";
                $mod_builder->{'raw_tags'}{ $alias } = 1;
            }
        }
    }
    
    if( $type eq 'raw' ) {
        $mod_builder->{'raw_tags'}{ $tagname } = 1;
    }
}

# aka run_tag
sub process_tag( modXML, xml, modinfo, ln ) {
    my $tags = $mod_builder->{'curTags'};
    my $taghash = $mod_builder->{'taghash'};
    
    #my $key = $xml->{'_key'};
    my $key = Melon::Builder::builder::get_first_key( $xml );
    
    my $tagdata = $taghash->{ $key } ||= {};
    
    my $metacode = $xml->{ $key };
    if( !ref( $metacode ) && $metacode =~ m/^\s*$/ ) { $metacode = {}; }
    
    my $params = {
        modXML => $modXML, # xml from build config file for the module
        metacode => $metacode, # the xml node of the tag being run
        tagdata => $tagdata,
        modInfo => $modinfo, # hash containing some basic info about the module
        builder => $mod_builder,
        ln => $ln
    };
        
    if( $tags->{ $key } ) {
        my $info = $tags->{ $key };
        my $func = $info->{'func'};
        return $func->( $info->{'mod'}, %$params );
    }

    return 0;
}