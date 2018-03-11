# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

# TODO: Generate System.pm with getmod function
use Parse::XJR;
use XML::Bare qw/forcearray/;

sub init {
    $self->{'build_id'} = $mod_uuid->new_id();
    $self->{'lang'} = 'perl';
}

sub setlang( lang ) {
    $self->{'lang'} = $lang;
}

sub get_info_filename {
    my $name = $mod_builder->{'name'};
    return "systems/$name.xml";
}

sub write_info_file( modhash ) {
    my $ns = $mod_builder->{'namespace'};
    my $pkg = $mod_builder->{'pkg'};
    my $name = $mod_builder->{'name'};
    my $dir = $mod_builder->{'dir'};
    my $path = "$dir/$ns/";
    my $lang = $self->{'lang'};
    
    $path = abs_path($path);
    my $lib = "$dir/";
    $lib = abs_path($lib);
    
    my $modText = '';
    for my $modName ( keys %$modhash ) {
        my $modInfo = $modhash->{ $modName };
        my $hasTagText = $modInfo->{'hasTags'} ? 'hasTags=1' : '';
        $modText .= "<mod name='$modName' $hasTagText/>\n";
    }
    
    my $versionXML = $global_version_current->getXML();
    my $buildId = $self->{'build_id'};
    
    my $jsdepText = '';
    if( $lang eq 'js' ) {
        $jsdepText = XML::Bare::Object::xml( 0, { jsdep => $mod_builder->{'jsdep'} } );
    }    
    
    my $cssText = '';
    if( $lang eq 'js' ) {
        $cssText = XML::Bare::Object::xml( 0, { css => $mod_builder->{'css'} } );
    }
    
    <tpl in=direct out=info>
        <xml>
            <build_id>*{buildId}</build_id>
            <name>*{name}</name>
            <package>*{pkg}</package>
            <path>*{path}</path>
            <lib>*{lib}</lib>
            <lang>*{lang}</lang>
            *{jsdepText}
            *{cssText}
            *{modText}
            *{versionXML}
        </xml>
    </tpl>
    
    write_file( "systems/$name.xml", $info );
    if( $self->{'lang'} eq 'js' ) {
        my $jsa = xjr_to_jsa( $info );
        $jsa =~ s/'/"/g;
        write_file( "systems/$name.jsa", $jsa );
    }
}

sub load_systems( systems ) {
    my $lang = $self->{'lang'};
    
    my $systemsR = $mod_builder->{'systems'} = {};
    
    my $importedModules = $mod_builder->{'importedModules'} = {};
    my $systemCreate;
    if( $lang eq 'perl' ) {
        $systemCreate = "my \$systems = \$self->{'systems'} = {};\n";
        $systemCreate .= "my \$importedModules = \$self->{'importedModules'} = {};\n";
    }
    if( $lang eq 'js' ) {
        $systemCreate = "var systems = this.systems = {};\n";
        $systemCreate .= "var importedModules = this.importedModules = {};\n";
    }
    if( $lang eq 'c' ) {
        $systemCreate .= "systemSetC systems;\n";
        $systemCreate .= "importedSetC importedModules;\n";
    }
    
    for my $system ( @$systems ) {
        my $sysName = $system->{'name'};
        my $sysLang = $system->{'lang'} || 'perl';
        my $file = $system->{'file'};
        
        next if( $systemsR->{ $sysName } );
        
        print "Loading system info file $file\n";
        my ( $ob, $systemInfo ) = XML::Bare->simple( file => $file );
        $systemInfo = $systemInfo->{'xml'};
        
        $global_version_current->trackUsedSystem( $sysName, ( $systemInfo->{'build_id'} || '?' ), $sysLang, $systemInfo->{'name'} );
        my $modInfoSet = forcearray( $systemInfo->{'mod'} );
        my %modInfoHash;
        my @tagMods;
        for my $mod ( @$modInfoSet ) {
            my $modName = $mod->{'name'};
            if( $mod->{'hasTags'} ) {
                push( @tagMods, $modName );
            }
            $modInfoHash{ $modName } = $mod;
        }
        
        my $path = $systemInfo->{'path'};
        my $package = $systemInfo->{'package'};
        my $lib = $systemInfo->{'lib'};
        
        my $sys = 0;
        if( $sysLang eq 'perl' ) {
            # System is loaded within the builder so that any tags it has can be used
            # Problematically any configuration that system has is being ignored here. TODO
            my $pmFile = "${path}/systemx.pm";
            
            # Deal with the fact that the builder essentially reloads portions of itself
            my $short = substr($package,0,-2)."::systemx";
            $self->unload_module($short);
            if( $package =~ m/Core2/ ) {
                $self->unload_module("Melon::Core::systemx");
            }
            
            require $pmFile or die "Could not load pm file $pmFile";
            $sys = "${package}systemx"->new( builder => $mod_builder, tagsystem => $mod_tagsystem, lang => $lang );
            $systemsR->{ $sysName } = $sys;
        }
        
        # Generate configuration blocks for imported modules
        my $confs = forcearray( $system->{'conf'} );
        my $modConfs = '';
        my %confdone;
        if( $lang eq 'perl' ) {
            for my $conf ( @$confs ) {
                my $modName = $conf->{'mod'};
                $confdone{ $modName } = 1;
                my $xmlText = XML::Bare::Object::xml( 0, { xml => $conf } );
                <tpl append in=direct out=systemCreate>
                    my $*{sysName}_*{modName}_conf_xml = <<'ENDEND';
                    *{xmlText}
ENDEND
                    my ( $*{sysName}_*{modName}_ob, $*{sysName}_*{modName}_conf ) = XML::Bare->simple( text => $*{sysName}_*{modName}_conf_xml );
                    $*{sysName}_*{modName}_conf = $*{sysName}_*{modName}_conf->{'xml'};
                    
                    if( $_params{'conf_*{modName}'} ) {
                        my $curConf = $_params{'conf_*{modName}'};
                        if( ref( $curConf ) ne 'ARRAY' ) { $curConf = [ $curConf ]; }
                        $*{sysName}_*{modName}_conf = [ @$curConf, $*{sysName}_*{modName}_conf ];
                    }
                </tpl>
                
                $modConfs .= "conf_${modName} => \$${sysName}_${modName}_conf,\n";
            }
        }
        if( $sysLang eq 'js' && $lang eq 'js' ) {
            for my $conf ( @$confs ) {
                my $modName = $conf->{'mod'};
                $confdone{ $modName } = 1;
                my $confJsa = xjr_to_jsa( $conf );
                <tpl append in=direct out=systemCreate>
                    var *{sysName}_*{modName}_conf_jsa = *{''confJsa};
                    var *{sysName}_*{modName}_conf = JsaToDC( *{sysName}_*{modName}_conf_jsa );
                    
                    if( $params.conf_*{modName} ) {
                        var curConf = $params.conf_*{modName};
                        if( !$curConf.length ) { curConf = [ curConf ]; }
                        *{sysName}_*{modName}_conf = [ curConf, *{sysName}_*{modName}_conf ];
                    }
                </tpl>
                
                $modConfs .= "conf_${modName}: ${sysName}_${modName}_conf,\n";
            }
        }
        if( $lang eq 'c' ) {
            for my $conf ( @$confs ) {
                my $modName = $conf->{'mod'};
                $confdone{ $modName } = 1;
                my $xmlText = XML::Bare::Object::xml( 0, { xml => $conf } );
                <tpl append in=direct out=systemCreate>
                    xmlOb **{sysName}_*{modName}_conf = new xmlOb( *{''xmlText} );
                    xmlObArray **{sysName}_*{modName}_conf_arr;
                    
                    if( params->keyExists('conf_*{modName}') ) {
                        *{sysName}_*{modName}_conf_arr = params->get( 'conf_*{modName}' );
                        curConf.append( *{sysName}_*{modName}_conf );
                    }
                    else {
                        xmlObArray **{sysName}_*{modName}_conf = new xmlObArray();
                        *{sysName}_*{modName}_conf.append( *{sysName}_*{modName}_conf );
                    }
                </tpl>
                
                $modConfs .= "->param( 'conf_${modName}', ${sysName}_${modName}_conf )\n";
            }
        }
        # Pass along configuration of imported modules that we are not extending
        my $imports = forcearray( $system->{'import'} );
        for my $import ( @$imports ) {
            my $modName = $import->{'mod'};
            if( !$confdone{ $modName } ) {
                if( $lang eq 'perl' ) {
                    <tpl append in=direct out=systemCreate>
                        my $*{sysName}_*{modName}_conf = {};
                        if( $_params{'conf_*{modName}'} ) {
                            $*{sysName}_*{modName}_conf = $_params{'conf_*{modName}'};
                        }
                    </tpl>
                }
                if( $sysLang eq 'js' && $lang eq 'js' ) {
                    <tpl append in=direct out=systemCreate>
                        var *{sysName}_*{modName}_conf = {};
                        if( $params.conf_*{modName} ) {
                            *{sysName}_*{modName}_conf = $params.conf_*{modName};
                        }
                    </tpl>
                }
            }
        }
        
        # use lib '$lib'; - Not using library so that root index file can change where to load things from
        # require \"${path}/systemx.pm\"; - Not using full path require; also because it forces the directory
        
        if( $lang eq 'perl' ) {
            <tpl append out=systemCreate in=direct>
                #my $*{sysName}modules = $systems->{*{''sysName}} = {};
                {
                    no warnings 'redefine';
                    require *{package}systemx;
                }
                my $system_*{sysName} = $systems->{*{''sysName}} = "*{package}systemx"->new(
                    tagsystem => $_params{'tagsystem'},
                    lang => ( $_params{'lang'} || 'perl' ),
                    *{modConfs}
                );
            </tpl>
        }
        if( $sysLang eq 'js' && $lang eq 'js' ) {
            my $pkgvar = $package;
            $pkgvar =~ s/::/_/g;
            my $sysNameCap = $systemInfo->{'name'};
            <tpl append out=systemCreate in=direct>
                var *{sysName}modules = systems[*{''sysName}] = {};
                // require *{pkgvar}systemx;
                var system_*{sysName} = new MOD_*{pkgvar}systemx( {
                    tagsystem: $params.tagsystem,
                    *{modConfs}
                } );
                var loader = $params.loader;
                if( loader ) loader.setSystemInst( *{''sysNameCap}, system_*{sysName} );
            </tpl>
        }
        
        #my $imports = forcearray( $system->{'import'} );
        for my $import ( @$imports ) {
            my $modName = $import->{'mod'};
            #my $mod = $sys->getmod( $modName );
            $importedModules->{ $modName } = 1;#$mod;
            
            if( $lang eq 'perl' ) {
                #$systemCreate .= "\$${sysName}modules->{'$modName'} = \$system_$name->getmod('$modName');\n";
                $systemCreate .= "\$importedModules->{'$modName'} = \$system_$sysName->getmod('$modName');\n";
                $systemCreate .= "\$mods->{'$modName'} = \$system_$sysName->getmod('$modName');\n";
            }
            if( $sysLang eq 'js' && $lang eq 'js' ) {
                #$systemCreate .= "\$${sysName}modules->{'$modName'} = \$system_$name->getmod('$modName');\n";
                $systemCreate .= "importedModules.$modName = system_$sysName.getmod('$modName');\n";
                $systemCreate .= "mods.$modName = system_$sysName.getmod('$modName');\n";
            }
        }
        
        if( $sysLang eq 'perl' && $lang eq 'perl' ) {
            if( @tagMods ) {
                my @mods_with_tags;
                for my $tagModName ( @tagMods ) {
                    #print "Loading tags for build use from '$tagModName'\n";
                    my $tagmod = $sys->getmod($tagModName);
                    if( $tagmod ) {
                        #$self->init(%params) if( defined( &systemx::init ) );
                        
                        my $setup = "${package}${tagModName}::setup_tags";
                        if( defined( &$setup ) ) {
                            push( @mods_with_tags, $tagModName );
                            $tagmod->setup_tags( $mod_tagsystem, lang => $lang );
                        }
                    }
                }
                if( @mods_with_tags ) {
                    $mod_builder->{'mods_with_tags'} = \@mods_with_tags;
                }
            }
        }
    }
    $mod_builder->{'systemCreate'} = $systemCreate;
}

sub unload_module( ns ) {
    no strict 'refs';
    my @subs = keys %{"$ns\::"};
    if( @subs ) {
        #print "Unloading $ns\n";
    }
    for my $sub ( @subs ) {
        my $sym = "$ns\::$sub";
        #print "Removing $sym\n";
        eval { undef &$sym };
        warn "$sym: $@" if $@;
    }
}