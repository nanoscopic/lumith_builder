# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init {
    $self->{'schemas'} = {};
}

sub tag_xml_schema {
    <tag name="xml_schema" type="raw" />
    <param name="metacode" var="tag" />
    
    my $xmltext = $tag->{'raw'};
    my $name = $tag->{'name'};
    my ( $ob, $xml ) = XML::Bare->new( text => $xmltext );
    $self->{'schemas'}{ $name } = $xml;
    return '';
}

sub tag_xml_db {
    <tag name="xml_db" type="raw" />
    <param name="metacode" var="tag" />
    
    # Generate modules based off schema
    my $name = $tag->{'name'};
    my $schema = $tag->{'schema'};
    my $schemas = $self->{'schemas'};
    my $var = $tag->{'var'} || $name;
    my $ob;
    my $xml = $schemas->{ $schema };
    if( !$xml ) {
        ( $ob, $xml ) = XML::Bare->new( file => $schema );
    }
    my $actions = $self->gencode_at_level( "xml_$name", 1, $xml );
    
    # Generate code for init to read in a specific file
    if( $tag->{'file'} ) {
        my $file = $tag->{'file'};
        push( @$actions, {
            action => 'add_sub_text',
            sub => 'init',
            text => "\$self->{'xml_db_$name'} = \$mod_xml_$name->new_inst( file => $file );\n"
        }, {
            action => 'add_text',
            text => "\$$var = \$self->{'xml_db_$name'};\n"
        } );
    }
    my $xmlText = '';
    if( $tag->{'data'} ) {
        $xmlText = XML::Bare::Object::xml( 0, $tag->{'data'} );
    }
    elsif( $tag->{'raw'} ) {
        $xmlText = $tag->{'raw'};
    }
    if( $xmlText ) {
        $xmlText =~ s/\n/\\n/g;
        $xmlText =~ s/"/\\"/g;
        push( @$actions, {
            action => 'add_sub_text',
            sub => 'init',
            text => "my \$data_xml_$name = \"$xmlText\";\
    \$self->{'xml_db_$name'} = \$mod_xml_$name->new_inst( text => \$data_xml_$name );\n"
        }, {
            action => 'add_text',
            text => "my \$$var = \$self->{'xml_db_$name'};\n"
        } );
    }
    
    return $actions;
}

sub gencode_at_level( path, isRoot, xml ) {
    my @actions;
    
    my $functionText = '';
    my $modsText = '';
    
    if( !ref($xml) || ref($xml) ne 'HASH' ) {
        use Data::Dumper;
        confess "$xml is not a ref. xml=" . Dumper( $xml );
    }
    for my $keySpec ( keys %$xml ) {
        next if( $keySpec =~ m/^_/ );
        next if( $keySpec eq 'value' );
        
        my $min = 0;
        my $max = 0;
        my $keyName = '';
        if( $keySpec =~ m/(.+)\{([0-9]+),([0-9]+)\}$/ ) { # node{1,3}
            $keyName = $1;
            $min = $2;
            $max = $3;
        }
        elsif( $keySpec =~ m/(.+)\*$/ ) { # node* ( 0 or more )
            $keyName = $1;
            $min = 0;
            $max = 9999;
        }
        elsif( $keySpec =~ m/(.+)\+$/ ) { # node+ ( 1 or more )
            $keyName = $1;
            $min = 1;
            $max = 9999;
        }
        elsif( $keySpec =~ m/(.+)\?$/ ) { # node? ( 0 or 1 )
            $keyName = $1;
            $min = 0;
            $max = 1;
        }
        else {
            $keyName = $keySpec;
            $min = 1;
            $max = 1;
        }
        
        my $subSpec = $xml->{ $keySpec };
        if( ref( $subSpec ) eq 'ARRAY' ) {
            # Use first type to determine if this is a complex type or not ( struct, not string )
            my $first = $subSpec->[0];
            my $isObj = has_children( $first );
            if( $isObj ) {
                # Find the static specifiers that can be used to determine the type
                my $statics = $self->find_shared_static_keys( $subSpec );
                my $u = $self->find_unique_statics( $subSpec, $statics );
                my $branchKey = $u->[0]; # use the first unique static key; is good enough
                
                my %branchHash;
                for my $oneSpec ( @$subSpec ) {
                    my $branchVal = $oneSpec->{ $branchKey }{'value'};
                    my $branchModName = "xml_${path}_${keyName}_${branchKey}_$branchVal";
                    $branchHash{ $branchVal } = $branchModName;
                    $modsText .= "<mod name='$branchModName' />\n";
                    push( @actions, @{$self->gencode_at_level( $branchModName, 0, $oneSpec )} );
                }
                
                if( $max > 1 ) {
                    $functionText .= $self->gen_multi_access( $path, $keyName, $subSpec, $isObj, $branchKey, \%branchHash );
                }
                else {
                    $functionText .= $self->gen_single_access( $path, $keyName, $subSpec, $isObj, $branchKey, \%branchHash );
                }
                
            }
            else { # multiple accepptable values / expressions
            }
        }
        else {
            my $isObj = has_children( $subSpec );
            if( $max > 1 ) {
                $functionText .= $self->gen_multi_access( $path, $keyName, $subSpec, $isObj );
            }
            else {
                $functionText .= $self->gen_single_access( $path, $keyName, $subSpec, $isObj );
            }
            
            if( $isObj ) {
                push( @actions, @{$self->gencode_at_level( "${path}_$keyName", 0, $subSpec )} );
                $modsText .= "<mod name='${path}_$keyName' />\n";
            }
        }
    }
    
    <tpl in=direct out=moduleText>
        <header/>
        <construct>
          *{modsText}
        </construct>
        
        sub new_inst {
            <new_inst />
        }
        
        *{functionText}
    </tpl>
   
    if( $isRoot ) {
        <tpl append>
            sub init_inst {
                <param name='file' />
                <param name='text' />
                my $a;
                my $b;
                if( $file ) {
                    ( $a, $b ) = XML::Bare->new( file => $file );
                }
                if( $text ) {
                    ( $a, $b ) = XML::Bare->new( text => $text );
                }
                $self->{'node'} = $b;
            }
        </tpl>
    }
    else {
        <tpl append>
            sub init_inst {
                <param name='node' />
                $self->{'node'} = $node;
            }
        </tpl>
    }
    
    <tpl append>
        sub value {
            return $self->{'node'}{'value'};
        }
    </tpl>
    
    my $filename = $path;
    $filename =~ s/^xml_//;
    push( @actions, {
        action => "create_module",
        file => "gen_mod/XML/$filename.pm",
        name => "$path",
        text => $moduleText,
        multiple => 1
    } );
    return \@actions;
}

sub find_unique_statics( specs, statics ) {
    my @unique;
    for my $static ( @$statics ) {
        push( @unique, $static ) if( $self->is_static_unique( $specs, $static ) );
    }
    return \@unique;
}

sub is_static_unique( specs, key ) {
    my %counts;
    for my $spec ( @$specs ) {
        my $val = $spec->{ $key }{'value'} || '--undef--';
        $counts{ $val }++;
        if( $counts{ $val } > 1 ) {
            return 0;
        }
    }
    return 1;
}

sub find_shared_static_keys( specs ) {
    my %static_counts;
    
    my $numspecs = scalar @$specs;
    
    for my $spec ( @$specs ) {
        #use Data::Dumper;
        #print "Spec: " . Dumper( $spec );
        my $statics = $self->get_static_keys( $spec );
        #print "Static keys: ". Dumper( $statics );
        for my $static ( @$statics ) {
            #print "Static: ".Dumper($static);
            $static_counts{ $static }++;
        }
    }
    #print "Counts: " . Dumper( \%static_counts );
    
    my @statics;
    for my $key ( keys %static_counts ) {
        my $count = $static_counts{ $key };
        push( @statics, $key ) if( $count == $numspecs );
    }
    #print "Shared statics: ".Dumper( \@statics );
    return \@statics;
}

sub get_static_keys( spec ) {
    my @statics;
    for my $key ( keys %$spec ) {
        next if( $key =~ m/^_/ );
        next if( $key eq 'value' );
        my $sub = $spec->{ $key };
        push( @statics, $key ) if( !has_children( $key ) );
    }
    return \@statics;
}

psub has_children {
    my $node = shift;
    return 0 if( !ref( $node ) );
    #confess "node is not a reference" if( !ref( $node ) );
    for my $key ( keys %$node ) {
        next if( $key =~ m/^_/ );
        next if( $key eq 'value' );
        return 1;
    }
    return 0;
}

sub gen_multi_access( path, name, node, isObj, branchKey, branchHash ) {
    <tpl in=direct out=code>
        sub get_*{name}s {
            my $nodes = forcearray( $self->{'node'}{*{''name}} );
    </tpl>

    if( $isObj ) {
        <tpl append>
            my @res;
            for my $node ( @$nodes ) {
        </tpl>        
        
        if( $branchKey ) {
            <tpl append>
                my $compare = $node->{*{''branchKey}}{'value'};
            </tpl>
            
            for my $keyVal ( keys %$branchHash ) {
                my $mod = $branchHash->{ $keyVal };
                <tpl append>
                    if( $compare eq *{''keyVal} ) {
                        push( @res, $mod_*{mod}->new_inst( node => $node );
                        next;
                    }
                </tpl>
            }
        }
        else {
            <tpl append>
                push( @res, $mod_*{path}_*{name}->new_inst( node => $node );
            </tpl>
        }
        <tpl append>
            }
            return \@res;
        </tpl>
    }
    else {
        <tpl append>
            return $nodes;
        </tpl>
    }
    $code .= "\n}\n";

    return $code;
}

sub gen_single_access( path, name, node, isObj, branchKey, branchHash ) {
    <tpl in=direct out=code>
        sub get_*{name} {
            my $node = $self->{'node'}{*{''name}};
    </tpl>
    
    if( $isObj ) {
        if( $branchKey ) {
            <tpl append>
                my $compare = $node->{*{''branchKey}}{'value'};
            </tpl>
            
            for my $keyVal ( keys %$branchHash ) {
                my $mod = $branchHash->{ $keyVal };
                <tpl append>
                    if( $compare eq *{''keyVal} ) {
                        return $mod_*{mod}->new_inst( node => $node );
                    }
                </tpl>
            }
        }
        else {
            <tpl append>
               return $mod_*{path}_*{name}->new_inst( node => $node );
            </tpl>
        }
        $code .= "\n}\n";
    }
    else {
        $code .= "return \$node->{'value'};\n}\n";
    }
    
    return $code;
}