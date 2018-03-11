# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init {
    $self->{'lang'} = 'perl';
}

sub setlang( lang ) {
    $self->{'lang'} = $lang;
}

sub write( subs, module, modinfo ) {
    my $$output = '';
    my $$tracedO = '';
    my $lang = $self->{'lang'};
    my $trace = $mod_builder->{'trace'}; # flag if tracing is enabled
    
    my %build_globals;
    if( $lang eq 'js' ) {
        my $pkgvar = $mod_builder->{'pkgvar'};
        my $modname = $modinfo->{'name'};
        %build_globals = (
            instanceClass => "MOD_$pkgvar${modname}_inst"
        );
    }
    # "final stage" - all xml reduced already
    for my $cursub ( @$subs ) {
        $mod_builder->{'cursub'} = $cursub;
        my $subName  = $cursub->{'name'};
        my $subParts = $cursub->{'parts'};
        my $subLn = $cursub->{'ln'};
        
        my $subOutput = '';
        my $subOutputTraced = '';
        
        if( $cursub->{'type'} ne 'init' ) {
            cut_ending_paran( $subParts );
        }
        
        for my $part ( @$subParts ) {
            next if( !$part );
            my $type = $part->{'type'};
            if( $type eq 'xml' ) {
                print Dumper( $part );
                die "xml parts still present in final stage";
            }
            if( $type eq 'sub' ) {
                my $name = $part->{'name'};
                next;
            }
            if( $type eq 'line' ) {
                my $text = $part->{'text'};
                $text =~ s/\%\{([a-zA-Z0-9_]+)\}/$build_globals{$1}/ge;
                
                my $traced = $text;
                my $ln = $part->{'ln'} || '?';
                
                if( $text =~ m/;\n$/ && $ln ) {
                    if( $lang eq 'perl' ) {
                        $text =~ s/\n$/#\@$ln\n/;
                    }
                    if( $lang eq 'js' || $lang eq 'c' ) {
                        $text =~ s|\n$|//\@$ln\n|;
                    }
                }
                $traced =~ s/\n$/#\@$ln\n/;
                
                $subOutput .= $text;
                $subOutputTraced .= $traced;
            }
        }
          
        #print "curSub: " . Dumper( $cursub );
        if( $cursub->{'type'} ne 'init' ) {
            my $subEnd = "}\n";
            my $subStart = $self->run_sub(
                modXml => $module,
                metacode => $cursub,
                modInfo => $modinfo,
                ln => $subLn,
                trace => $trace
            );
            #print "subStart: " . Dumper( $subStart );
            if( $lang eq 'perl' ) {
                $subOutput = "sub $subName { #\@$subLn\n" . $subStart . $subOutput . $subEnd;
                $subOutputTraced = "sub $subName { #\@$subLn\n" . $subStart . $subOutputTraced . $subEnd;
            }
            if( $lang eq 'js' ) {
                my $pkgvar = $mod_builder->{'pkgvar'};
                my $modname = $modinfo->{'name'};
                $subOutput = "MOD_$pkgvar$modname.prototype.$subName = function" . $subStart . $subOutput . $subEnd;
                $subOutputTraced = "MOD_$pkgvar$modname.prototype.$subName = function" . $subStart . $subOutput . $subEnd;
            }
            if( $lang eq 'c' ) {
                my $params = $self->sub_params(
                    modXml => $module,
                    metacode => $cursub,
                    modInfo => $modinfo,
                    ln => $subLn,
                    trace => $trace
                );
                my $retType = $cursub->{'retType'};
                $subOutput = "$retType MOD_$pkgvar$modname::$subName($params) { #\@$subLn\n" . $subStart . $subOutput . $subEnd;
            }
        }
        
        $self->reset_sub();
        my $dests = $self->{'sym_dest'};
        while( $subOutput =~ m/[^\\\$]\$([a-zA-Z]{3})[^[a-zA-Z0-9_]/g ) {
            $dests->{ $1 } = 1;
        }
        
        $subOutput =~ s/([^\\])\$\$([a-zA-Z0-9_]+)/assign_dest( $self, $1, $2 )/ge;
                    
        $$output .= $subOutput;
        $$tracedO .= $subOutputTraced;
    }
    return ( $$output, $$tracedO );
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

sub reset_sub {
    $self->{'sym_map'} = {};
    $self->{'sym_dest'} = {};
    my $test = 2;
    my $x = "a\$$test";
}

sub assign_dest( char, in ) {
    my $map = $self->{'sym_map'};
    if( my $sym = $map->{$in} ) {
        return $char.'$'.$sym;
    }
    my $dests = $self->{'sym_dest'};
    for( my $i=0;$i<20;$i++ ) {
        my $newsym = $self->rand_sym();
        next if( $dests->{$newsym} );
        $dests->{$newsym} = 1;
        $map->{$in} = $newsym;
        return $char.'$'.$newsym;
    }
    if( $dests->{$in} ) {
        die "Cannot find a symbol to assign for obfuscation and the original symbol has been used";
    }
    return $char.'$'.$in;
}

sub rand_sym {
    return chr( ord('a')+rand(26) ).chr( ord('A')+rand(26) ).chr( ord('a')+rand(26) );
}

sub sub_params {
    <param name="modXML" var="module" />
    <param name="metacode" var="sub" />
    <param name="modInfo" />
    <param name="ln" />
    <param name="trace" />
    
    my $lang = $self->{'lang'};
    my $subName = $sub->{'name'};
    my $modName = $modInfo->{'name'};
    
    my $params = $sub->{'params'};
    
    my $out = "";
    
    if( $lang eq 'c' ) {
        $out = join( ',', @$params );
    }
    
    return $out;
}

sub run_sub {
    <param name="modXML" var="module" />
    <param name="metacode" var="sub" />
    <param name="modInfo" />
    <param name="ln" />
    <param name="trace" />
    
    my $lang = $self->{'lang'};
    my $subName = $sub->{'name'};
    my $modName = $modInfo->{'name'};
    
    my $params = $sub->{'params'};
    
    my $out = "";
    if( $lang eq 'perl' ) {
        $out .= "    my \$self=shift;\n" if( $subName ne 'new_inst' );
        
        for my $param ( @$params ) {
            $out .= "    my \$$param = shift;\n";
        }
        
        $out .= "  my \%_params = \@_;\n" if( $subName ne 'new_inst' );
        if( $trace ) {
            $out .= "  my \$_trId = \$mod_log->{'trId'}++;\n";
            $out .= "  \$mod_log->tr_subentry( \$_trId, '$modName', '$subName', \\\%_params );\n";
        }
    }
    if( $lang eq 'js' ) {
        #$out .= "    my \$self=shift;\n" if( $subName ne 'new_inst' );
        $out .= "(";
        
        if( @$params ) {
            for my $param ( @$params ) {
                $out .= "\$$param,";
            }
            #$out = substr( $out, 0, -1 );
        }
        
        if( $subName ne 'new_inst' ) {
            $out .= "\$params) {\n" ;
        }
        else {
            $out .= ") { //\@$ln\n" ;
        }
        
        #$out .= "  var \%_params = \@_;\n" ;
    }
    
    my $vars = $sub->{'vars'};
    
    #print "vars: ".Dumper( $vars );
    my %doneVars;
    
    for my $var ( @$vars ) {
        my $fromself = $var->{'self'};
        next if( $doneVars{ $fromself } );
        $doneVars{ $fromself } = 1;
        if( $lang eq 'perl' ) {
            if( $fromself ) {
                my $tovar = $var->{'var'} || $fromself;
                $out .= "    my \$$tovar = \$self->{'$fromself'};\n";
            }
            my $fromname = $var->{'name'};
            if( $fromname ) {
                my $tovar = $var->{'var'} || $fromname;
                $out .= "    my \$$tovar = \$_params{'$fromname'};\n";
            }
        }
        if( $lang eq 'js' ) {
            if( $fromself ) {
                my $tovar = $var->{'var'} || $fromself;
                $out .= "    var \$$tovar = this.$fromself;\n";
            }
            my $fromname = $var->{'name'};
            if( $fromname ) {
                my $tovar = $var->{'var'} || $fromname;
                $out .= "    var \$$tovar = \$_params.$fromname;\n";
            }
        }
    }
    
    return $out;
}