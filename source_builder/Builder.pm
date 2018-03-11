# Copyright (C) 2018 David Helkowski

<header/>
<construct/>

sub init {
    $self->{'action_handlers'} = {};
    $self->{'sys'} = $SYS;
    $self->{'lang'} = 'perl';
    $self->{'trace'} = 0;
}

sub setlang( lang ) {
    $self->{'lang'} = $lang;
}

sub init2 {
    <param name="file" />
    <param name="lang" />
    
    if( $lang ) {
        $self->{'lang'} = $lang;
    }
    else {
        $lang = $self->{'lang'};
    }
    
    $mod_taghandlers->setlang( $lang );
    $mod_subwriter->setlang( $lang );
    $mod_systemgen->setlang( $lang );
    $global_version_current = $mod_versiontracker->new_inst();
    
    $global_version_current->trackInputFile( $file, { type => "system_conf" } );
    my ( $ob, $xml ) = XML::Bare->simple( file => $file );
    $xml = $self->{'xml'} = $xml->{'xml'};
    if( $lang eq 'js' ) {
        $self->{'jsdep'} = $xml->{'jsdep'};
        $self->{'css'} = $xml->{'css'};
    }
    
    # Let direct parameter take precedence
    # After that use parameter in XML file
    # Finally just use a default value
    my $ns = $_params{'namespace'} || $xml->{'namespace'} || 'Melon/Default';
    $self->{'namespace'} = $ns;
    
    my $name = $_params{'name'};
    if( !$name && $xml->{'name'} ) {
        $name = $xml->{'name'};
    }
    $self->{'system_name'} = $self->{'name'} = $name;
    
    my $dir = $self->{'dir'} = $_params{'dir'} || 'built';
    $global_version_prev = $mod_versiontracker->new_inst( file => $mod_systemgen->get_info_filename() );
    
    $global_version_current->trackVars( { sys_name => $name, sys_ns => $ns } );
    
    if( ! -e "$dir/$ns" ) {
        my @parts = split( '/', $ns );
        my $curpath = $dir;
        for my $part ( @parts ) {
            $curpath .= "/$part";
            if( ! -e $curpath ) {
                mkdir $curpath;
            }
        }
    }
    
    # Melon/User -> Melon::User::
    my $pkg = $ns;
    $pkg =~ s|/|::|g;
    $pkg .= "::";
    $self->{'pkg'} = $pkg;
    my $pkgvar = $pkg;
    $pkgvar =~ s/::/_/g;
    $self->{'pkgvar'} = $pkgvar;
}

sub parse_xml_parts( parts ) {
    my $hasXmlPart = 0;
    for my $part ( @$parts ) {
        next if( $part->{'type'} ne 'xml' );
        $hasXmlPart = 1;
        my $xmlText = $part->{'xmlText'};
        if( !$xmlText ) {
            print Dumper( $part );
            die;
        }
        my ( $o1, $x1 ) = XML::Bare->simple( text => $part->{'xmlText'} );
        $part->{'xml'} = $x1;
    }
    return $hasXmlPart;
}

psub get_first_key {
    my $hash = shift;
    for my $key ( keys %$hash ) {
        next if( $key =~ m/^_/ );
        return $key;
    }
    return '';
}

sub setup_tag_stages {
    my $raw_tags = $self->{'raw_tags'} = {};
    my $stages = $mod_taghandlers->setup_stages();
    
    my $stage_hash = $self->{'stage_hash'} = {};
    for my $stage ( @$stages ) {
        my $name = $stage->{'name'};
        $stage_hash->{ $name } = $stage;
    }
    
    return $stages;
}

sub build_module( module ) {
    <param name="trace" />
    
    my $lang = $self->{'lang'};
    my $module_build_res = $self->{'module_build_result'} = {};
    my $taghash = $self->{'taghash'} = {};
    my $modhash = $self->{'modhash'};
    $self->{'curmod'} = $module;
    my $modname = $module->{'name'};
    print "\n===== Processing module $modname =====\n";
    my %modinfo = ( name => $modname, buildXML => $module );
    $modhash->{ $modname } = \%modinfo;
    $module->{'_cpan'} = forcearray( $module->{'cpan'} );
    
    my $file = $module->{'file'};
    my $data;
    my $rt;
    if( ( $rt = ref( $file ) ) && $rt eq 'ARRAY' ) {
        for my $aFile ( @$file ) {
            $data .= read_file( $aFile );
        }
    }
    else {
        $data = read_file( $file );
    }
    
    my @rawlines = split(/\n/, $data);
    my @lines;
    my $numlines = scalar @rawlines;
    for( my $ln=1;$ln<=$numlines;$ln++) {
        my $rawline = $rawlines[$ln-1];
        push( @lines, { text => $rawline, ln => $ln } );
    }
    
    my $parts = $self->split_lines_to_parts( \@lines );
    $self->parse_xml_parts( $parts );
    
    $self->{'subhash'} = {};
    my $subs = $self->{'subs'} = $self->split_parts_to_subs( $parts );
    my $subhash = $self->{'subhash'};
    #print Dumper( $subhash );
    
    # Run through the various tag stages
    my $stages = $self->{'tag_stages'};
    for my $stage ( @$stages ) {
        $self->{'curTags'} = $stage->{'tags'};
        $self->{'stage'} = $stage;
                    
        my $stageName = $stage->{'name'};
        
        #print " Stage $stageName:\n";
        if( $stageName eq 'preconstruct' ) {
            # Automatically recognize module usage
            for my $cursub ( @$subs ) {
                my $subName  = $cursub->{'name'};
                my $subParts = $cursub->{'parts'};
                
                for my $Apart ( @$subParts ) {
                    next if( $Apart->{'type'} ne 'line' );
                    my $part = $Apart->{'text'};
                    my %usedMods;
                    while( $part =~ m/\$mod_([a-zA-Z0-9_]+)/g ) {
                        $usedMods{$1} = ( $subName eq 'init' ) ? 'normal' : 'delayed';
                    }
                    if( $trace ) {
                        if( $lang eq 'perl' ) {
                            # pass local trace ID forward into all method calls to other modules
                            # Note that inner parantheses will cause this regular expression not to detect.
                            # This is not a perfect method...
                            # Note also this depends on the function being properly generated with a $_trId variables at the top.
                            $part =~ s/\$mod_([a-zA-Z0-9_]+)->([a-zA-Z0-9_]+)\(([^\(\)]+\))/\$mod_${1}->${2}($3,'_trId' => \$_trId)/g;
                            # pass local trace ID forward into all self calls
                            $part =~ s/\$self->([a-zA-Z0-9_]+)\(([^\(\)]+\))/\${self}->${1}($2,'_trId' => \$_trId)/g;
                        }
                    }
                    $part =~ s/\$global_([a-zA-Z0-9_]+)/\$SYS->{g}{$1}/g;
                    $Apart->{'text'} = $part;
                    for my $modName ( keys %usedMods ) {
                        my $depType = $usedMods{ $modName };
                        # Add the dependency so it is used within the construct tag
                        my $construct = $taghash->{'construct'} ||= {};
                        my $modules = $construct->{'modules'} ||= {};
                        if( !$modules->{ $modName } ) {
                            $modules->{ $modName } = { delayed => ( $depType eq 'delayed' ), var => "mod_$modName" }
                        }
                        elsif( $depType ne 'delayed' ) { # Overwrite currently delayed modules with non-delayed hard dependency
                            $modules->{ $modName } = { delayed => 0, var => "mod_$modName" }
                        }
                        
                        # Add the local variable to the sub
                        my $vars = $cursub->{'vars'};
                        push( @$vars, { self => "mod_$modName", var => "mod_$modName" } );
                    }
                }
            }
            next;
        }
        
        for my $cursub ( @$subs ) {
            $self->{'cursub'} = $cursub;
            $cursub->{'parts'} = $self->process_xml_parts( $module, \%modinfo, $cursub->{'parts'} );
        }
    }
    #print " ===Stages Finished===\n";
    
    my ( $output, $outputTraced ) = $mod_subwriter->write( $subs, $module, \%modinfo );
    
    my $ns = $self->{'namespace'};
    
    if( $lang eq 'perl' ) {
        $output .= "\n1;\n";
    }
    
    my $dir = $self->{'dir'};
    my $modulePath;
    my $modulePathTraced;
    
    if( $lang eq 'perl' ) {
        $modulePath = "$dir/$ns/$modname.pm";
        $modulePathTraced = "$dir/$ns/$modname.tpm";
    }
    if( $lang eq 'js' ) {
        $modulePath = "$dir/$ns/$modname.js";
        $modulePathTraced = "$dir/$ns/$modname.tjs";
    }
    if( $lang eq 'c' ) {
        $modulePath = "$dir/$ns/$modname.c";
        $modulePathTraced = "$dir/$ns/$modname.tc";
    }
    write_file( $modulePath, $output );
    write_file( $modulePathTraced, $outputTraced );
    $global_version_current->trackOutputFile( $file, { type => "mod", mod => $modname } );
    if( $lang eq 'perl' ) {
        $self->check_compile_perl( $modname, $modulePath, $output );
    }
    if( $lang eq 'c' ) {
        #$self->check_compile_c( $modname, $modulePath, $output );
    }
    
    return $module_build_res;
}

sub check_compile_perl( modName, modFile, gen ) {
    #use Capture::Tiny 'capture';
    #my $cmd = "perl -c $modFile";
    #my $errCode;
    #my ($out, $err) = capture { $errCode = system($cmd) };
    #return if( $errCode==0 );
    my $code = "perl -c $modFile 2>\&1";
    #print "Running $code\n";
    my $err = `$code`;
    my $errCode = $?;
    return if( $errCode==0 );
    
    my @genLines = split("\n",$gen);
    
    #Use of uninitialized value $b in concatenation (.) or string at test3.pl line 5.
    my @errLines = split("\n",$err);
    for my $line ( @errLines ) {
        if( $line =~ m/(.+) at [^ ]+ line (.+)(\.|,)/ ) {
            my $err = $1;
            my $ln = $2;
            print "Error in $modName\n  $err\n";
            my $approx_line = $self->get_approx_line( \@genLines, $ln );
            if( $approx_line eq '?' ) {
                print "  Built Line: $ln ( see $modFile )\n";
            }
            else {
                print "  Source Line: $approx_line\n";
            }
        }
    }
}

sub get_approx_line( lines, ln ) {
    my $totLines = scalar @$lines;
    my $offset = 0;
    for( my $lineNum=$ln-1;$lineNum<$totLines;$lineNum++ ) {
        my $line = $lines->[ $lineNum ];
        if( $line =~ m/#\@([0-9]+)/ ) {
            my $srcLN = $1;
            if( $offset ) { return "< $srcLN (approx)"; }
            return $srcLN;
        }
        $offset++;
    }
    return '?';
}

sub build {
    <param name="skipModules" />
    <param name="forceRebuild" />
    <param name="trace" />
    
    if( $trace ) {
        $self->{'trace'} = 1;
    }
    
    my $xml = $self->{'xml'};
    
    $self->setup_tag_stages();
    
    if( $xml->{'system'} ) {
        my $systems = forcearray( $xml->{'system'} );
        $mod_systemgen->load_systems( $systems );
    }
    
    $self->{'modhash'} = {};
    
    my %skipHash;
    if( $skipModules ) {
        for my $skipMod ( @$skipModules ) {
            print "Will skip module '$skipMod'\n";
            $skipHash{ $skipMod } = 1;
        }
    }
    
    my $modules = forcearray( $xml->{'module'} );
    
    for my $module ( @$modules ) {
        my $modName = $module->{'name'};
        my $file = $module->{'file'};
        my $rt;
        if( ( $rt = ref($file) ) && $rt eq 'ARRAY' ) {
            for my $aFile ( @$file ) {
                $global_version_current->trackInputFile( $aFile, { type => 'mod', mod => $modName } );
            }
        }
        else {
            $global_version_current->trackInputFile( $file, { type => 'mod', mod => $modName } );
        }
    }
    
    if( !$forceRebuild && $global_version_current->equals( $global_version_prev ) ) {
        print "Input files have not changed; continuing without rebuilt\n";
        return;
    }
    
    my $sysModule = 0;
    while( @$modules ) {
        my $module = shift @$modules;
        my $modName = $module->{'name'};
        if( $modName eq 'systemx' ) {
            $sysModule = $module;
            next;
        }
        next if( $skipHash{ $modName } );
        my $res = $self->build_module( $module, trace => $trace );
        if( $res->{'new_modules'} ) {
            print "Adding module(s):\n";
            for my $addMod ( @{$res->{'new_modules'}} ) {
                my $modDup = { %$addMod };
                $modDup->{'file'} = { value => $modDup->{'file'}, _att => 1 } if( $modDup->{'file'} );
                $modDup->{'name'} = { value => $modDup->{'name'}, _att => 1 } if( $modDup->{'name'} );
                $modDup->{'multiple'} = { value => $modDup->{'multiple'}, _att => 1 } if( $modDup->{'multiple'} );
                my $xml = XML::Bare::Object::xml( 0, { mod => $modDup } );
                print "  $xml";
            }
            unshift( @$modules, @{$res->{'new_modules'}} );
        }
    }
    
    $self->build_module( $sysModule );
        
    $mod_systemgen->write_info_file( $self->{'modhash'} );
}

sub register_action( action, func, mod ) {
    $self->{'action_handlers'}{$action} = { func => $func, mod => $mod };
}

sub process_xml_parts( module, modinfo, subParts ) {
    my $tags = $self->{'curTags'};
    my $cursub = $self->{'cursub'};
    my $subName  = $cursub->{'name'};
    my $taghash = $self->{'taghash'};
    my $subhash = $self->{'subhash'};
    my $module_build_result = $self->{'module_build_result'};
    my $actionHandlers = $self->{'action_handlers'};
    
    #print Dumper( $subParts );
    my $partsOut = [];
    for my $part ( @$subParts ) {
        next if( !$part );
        if( $part->{'type'} ne 'xml' ) {
            push( @$partsOut, $part );
            next;
        }
        my $ln = $part->{'ln'} || '?';
        #my $key = $part->{'xml'}{'_key'};
        my $key = get_first_key( $part->{'xml'} );
        if( !$key ) {
            print "No valid first key: ".Dumper($part);
        }
        #print Dumper( $part );
        #print "  tag $key\n";
        if( $tags->{$key} ) { # only process tags that are in this stage
            my $actions = $mod_tagsystem->process_tag( $module, $part->{'xml'}, $modinfo, $ln );
            
            if( my $reftype = ref( $actions ) ) {
                if( $reftype ne 'ARRAY' ) {
                    confess( "Result of running tag $key - > " . Dumper( $actions ) ); 
                }
                #print "Result: ".Dumper( $actions );
                for my $actionNode ( @$actions ) {
                    my $action = $actionNode->{'action'};
                    if( !$action ) {
                        print "Action has no type: ".Dumper( $actionNode );
                    }
                    #print "ACTION $action\n";
                    my $handler = $actionHandlers->{$action};
                    my $func = $handler->{'func'};
                    my $extraParts = $func->( $handler->{'mod'}, $actionNode, $taghash, $cursub, $subhash, module => $module, modinfo => $modinfo, ln => $ln );
                    if( $extraParts ) {
                        for my $extraPart ( @$extraParts ) {
                            next if( !%$extraPart );
                            $extraPart->{'ln'} = $ln;
                        }
                        push( @$partsOut, @$extraParts );
                    }
                }
                
                #if( ref( $part ) eq 'ARRAY' ) {
                #    push( @$partsOut, @$part );
                #}
                #else {
                #    $part->{'type'} = 'line';
                #    $part->{'text'} = '';
                #    push( @$partsOut, $part );
                #}
            }
            else {
                my $resultText = $actions;
                $part->{'text'} = $resultText;
                $part->{'type'} = 'line';
                push( @$partsOut, $part );
            }
        }
        else {
            #print "  skipping tag $key - not in this stage\n";
            push( @$partsOut, $part );
        }
    }
    #return $subParts;
    
    return $partsOut;
}

sub split_parts_to_subs( parts ) {
    my $subhash = $self->{'subhash'} ||= {};
    my @subs;
    
    my $cursub = { type => 'init' };
    my $curparts = [];
    $cursub->{'parts'} = $curparts;
    
    for my $part ( @$parts ) {
        my $type = $part->{'type'};
        if( $type eq 'sub' ) {
            push( @subs, $cursub );
            my $newSubName = $part->{'name'};
            my $subLn = $part->{'ln'} || '?';
            $curparts = [ $part ];
            $cursub = {
                type => 'sub',
                name => $newSubName,
                parts => $curparts,
                vars => $part->{'vars'},
                params => $part->{'params'},
                ln => $subLn
            };
            $subhash->{ $newSubName } = $cursub;
            next;
        }
        if( $type eq 'retType' ) {
            $cursub->{'retType'} = $part->{'retType'};
            next;
        }
        push( @$curparts, $part );
    }
    push( @subs, $cursub );
    
    return \@subs;
}

sub split_lines_to_parts( lines ) {
    my $incomment = 0;
    my $commentxml = '';
    my @parts;
    my $tagname = '';
    
    my $mode = "normal";
    my $rawBegin;
    my $rawEnd;
    
    my $raw_tags = $self->{'raw_tags'};
    
    while( @$lines ) {
        my $lineOb = shift @$lines;
        my $line;
        my $ln;
        if( !ref( $lineOb ) ) {
            $line = $lineOb;
            $ln = '?';
        }
        else {
            $line = $lineOb->{'text'};
            $ln = $lineOb->{'ln'};
        }
        if( $mode eq 'normal' ) {
            if( $line =~ m/^`(.+)/ ) { # raw line
                push( @parts, { type => 'line', text => "$1\n", ln => $ln } );
                next;
            }
            if( $line =~ m|^\s*<!--.+-->\s*$| ) { # xml style comment
                next;
            }
            if( $line =~ m|^\s*(<.+/>)$| ) { # self closing xml
                push( @parts, { type => 'xml', xmlText => "$1", ln => $ln } );
                next;
            }
            if( $line =~ m|^\s*<([a-zA-Z_]+)| ) { # start of XML block
                $tagname = $1;
                if( $line =~ m|</$tagname>\s*$| ) { # closing tag on the same line
                    push( @parts, { type => 'xml', xmlText => "$line", ln => $ln } );
                    next;
                }
                if( $raw_tags->{ $tagname } ) {
                    #print "Start of raw tag $tagname\n";
                    $commentxml = "$line<raw><![CDATA[";
                    $mode = 'rawtag';
                    $rawBegin = $ln + 1;
                    next;
                }
                if( $line =~ m/>\[\[$/ ) {
                    $line = substr( $line, 0, -2 );
                    $line .= "<![CDATA[";
                    #print "New line: `$line`\n";
                }
                $commentxml = "$line\n";
                $mode = 'xml';
                next;
            }
            #                  sub subname              ( param1
            if( $line =~ m/^\s*sub ([a-zA-Z0-9_-]+)\s*(\(\s*[a-zA-Z0-9()*_-]+\s*(,\s*[a-zA-Z0-9()*_-]+)*\s*\))?\s*\{\s*$/ ) {
                my $sub = $1;
                my $paramStr = $2;
                #print "paramsStr: " . Dumper( $paramStr ) . "\n";
                if( $paramStr ) {
                    #print "has param str\n";
                    $paramStr =~ s/\s//g;
                    $paramStr =~ s/^\(//;
                    $paramStr =~ s/\)$//;
                    my @paramParts = split(',',$paramStr);
                    push( @parts, {
                        type => 'sub',
                        name => $sub,
                        params => \@paramParts,
                        vars => [],
                        ln => $ln,
                        retType => 'void'
                    } );
                }
                else {
                    push( @parts, {
                        type => 'sub',
                        name => $sub,
                        params => [],
                        vars => [],
                        ln => $ln
                    } );
                }
                next;
            }
            if( $line =~ m/^\s*ret (.+)$/ ) {
                my $exp = $1;
                push( @parts, {
                    type => 'retType', # return type
                    retType => $exp,
                    ln => $ln
                } );
            }
            next if( $line =~ m/^\s*$/ ); # skip whitespace - could break heredocs
            next if( $line =~ m/^\s*#.+/ ); # skip whole line comments
            if( $line =~ m/^psub / ) {
                $line =~ s/^psub /sub /;
            }
            # TODO: deal with comments at end of lines... difficult...
            push( @parts, { type => 'line', text => "$line\n", ln => $ln } );
        }
        elsif( $mode eq 'rawtag' ) {
            if( $line =~ m|^\s*</([a-zA-Z_]+)>\s*$| ) {
                $rawEnd = $ln;
                my $tagend = $1;
                if( $tagend eq $tagname ) {
                    #print "End of raw tag: $tagname\n";
                    $mode = 'normal';
                    $commentxml .= "]]></raw></$tagname>";
                    #print Dumper( $commentxml );
                    push( @parts, { type => 'xml', xmlText => $commentxml, ln => $rawBegin } );
                    next;
                }
            }
            $line =~ s/]]>/||>/g; # prevent contents of raw tag from ending cdata
            $commentxml .= "$line\n";
        }
        elsif( $mode eq 'xml' ) {
            if( $line =~ m/>\[\[$/ ) {
                $line = substr( $line, 0, -2 );
                $line .= "<![CDATA[";
            }
            if( $line =~ m|^\s*<!--.+-->\s*$| ) { # xml style comment
                next;
            }
            $commentxml .= "$line\n";
            if( $line =~ m|^\s*(\]\]>)?</([a-zA-Z_]+)>$| ) {
                my $tagend = $2;
                if( $tagend eq $tagname ) {
                    $mode = 'normal';
                    push( @parts, { type => 'xml', xmlText => $commentxml, ln => $ln } );
                }
            }
            next;
        }
    }
    return \@parts;
}