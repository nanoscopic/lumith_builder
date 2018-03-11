# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

use Parse::XJR;

sub init {
    $self->{'lang'} = 'perl';
}

sub setlang( lang ) {
    $self->{'lang'} = $lang;
}

sub setup_stages {
    my $stages = $mod_builder->{'tag_stages'} = [
        {
            name => 'normal',
            tags => {
                header   => { func => \&tag_header  , mod => $self },
                var      => { func => \&tag_var     , mod => $self },
                page     => { func => \&tag_page    , mod => $self },
                tag      => { func => \&tag_tag     , mod => $self },
                param    => { func => \&tag_param   , mod => $self },
                new_inst => { func => \&tag_new_inst, mod => $self },
            }
        },
        {
            name => 'normal2',
            tags => {
            }
        },
        {
            name => 'preconstruct'
        },
        {
            name => 'final',
            tags => {
                construct => { func => \&tag_construct, mod => $self }
            }
        },
        {
            name => 'final2',
            tags => {
                sysblock => { func => \&tag_sysblock, mod => $self }
            }
        }
    ];
    return $stages;
}

sub tag_new_inst {
    <param name="metacode" var="node" />
    <param name="modInfo" var="modinfo" />
    
    my $modname = $modinfo->{'name'};
    my $pkg = $mod_builder->{'pkg'};
    
    my $lang = $self->{'lang'};
    
    my $out;
    if( $lang eq 'perl' ) {
        <tpl append in=direct out=out>
            my $root = shift;
            my $class = ref( $root );
            my %params = @_;
            my $self = bless { %$root }, $class;
            
            $self->init_inst(%params) if( defined( &*{pkg}*{modname}::init_inst ) && !$self->{'skipInit'} );
            return $self;
        </tpl>
    }
    if( $lang eq 'js' ) {
        my $pkgvar = $mod_builder->{'pkgvar'};
        <tpl append in=direct out=out>
            function MOD_*{pkgvar}*{modname}_inst( $params ) {
                if( MOD_*{pkgvar}*{modname}.prototype.init_inst ) this.init_inst( $params );
            }
            MOD_*{pkgvar}*{modname}.prototype.new_inst = function( $params ) {
                return new MOD_*{pkgvar}*{modname}_inst( $params );
            }
        </tpl>
        
        <tpl in=direct out=init>
            MOD_*{pkgvar}*{modname}_inst.prototype = this;
        </tpl>
        
        return [
            { action => 'add_text', text => $out },
            { action => 'add_sub_text', sub => 'init', text => $init }
        ];
    }
    return $out;
}

sub tag_construct {
    <param name="modXML" var="module" />
    <param name="metacode" var="node" />
    <param name="modInfo" var="modinfo" />
    <param name="builder" />
    
    my $conf = $node->{'conf'} || {};
    $modinfo->{'construct_conf'} = $conf;
    
    if( !$node || !ref( $node ) ) {
        $node = {};
    }
    my $mods = $node->{'mod'} ? forcearray( $node->{'mod'} ) : [];
    my %modByName;
    for my $mod ( @$mods ) {
        my $modName = $mod->{'name'};
        $modByName{ $modName } = $mod;
    }
        
    my $pkg = $mod_builder->{'pkg'};
    my $pkgvar = $mod_builder->{'pkgvar'};
    my $importedModules = $mod_builder->{'importedModules'};
    
    my $taghash = $builder->{'taghash'};
    my $constructHash = $taghash->{'construct'} || {};
    my $modulesFromHash = $constructHash->{'modules'} || {};
    
    for my $extraModName ( keys %$modulesFromHash ) {
        my $extraMod = $modulesFromHash->{ $extraModName };
        
        next if( $modByName{ $extraModName } );
        $modByName{ $extraModName } = {
            name => $extraModName,
            var => ( $extraMod->{'var'} || "mod_$extraModName" ),
            delayed => $extraMod->{'delayed'}
        };
    }
    
    my $modname = $modinfo->{'name'};
    #print "Construct for mod $modname\n";
    #print Dumper( \%modByName );
    #print Dumper( $node );
    my $copy = "";
        
    #print "  checking mods\n";
    
    my $deps;
    my $delayed_deps;
    my $imported_deps;
    if( ! ( $deps = $modinfo->{'deps'} ) ) {
        $deps = $modinfo->{'deps'} = {};
    }
    if( ! ( $delayed_deps = $modinfo->{'delayed_deps'} ) ) {
        $delayed_deps = $modinfo->{'delayed_deps'} = {};
    }
    if( ! ( $imported_deps = $modinfo->{'imported_deps'} ) ) {
        $imported_deps = $modinfo->{'imported_deps'} = {};
    }
    
    for my $modName ( keys %modByName ) {
        my $mod = $modByName{ $modName };
        
        my $delayed = $mod->{'delayed'};
        my $var = $mod->{'var'} || "mod_$modName";
        if( $importedModules->{ $modName } ) {
            $imported_deps->{ $modName } ||= {};
            $imported_deps->{ $modName }{ $var } = 1;
            next;
        }
        if( $delayed ) {
            $delayed_deps->{ $modName } ||= {};
            $delayed_deps->{ $modName }{ $var } = 1;
            next;
        }
        
        $deps->{ $modName } ||= {};
        $deps->{ $modName }{ $var } = 1;
        #print Dumper( $deps );
    }
    
    my $lang = $self->{'lang'};
    
    for my $depname ( keys %$deps ) {
        for my $var ( keys %{$deps->{$depname}} ) {
            #print "  Dep on mod $depname as var $var\n";
            if( $lang eq 'perl' ) {
                $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";
            }
            elsif( $lang eq 'js' ) {
                $copy .= "    this['$var'] = \$params['mod_$depname'] || 0;\n";
            }
        }
    }
    
    for my $depname ( keys %$imported_deps ) {
        for my $var ( keys %{$imported_deps->{$depname}} ) {
            #print "  Dep on mod $depname as var $var\n";
            if( $lang eq 'perl' ) {
                $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";
            }
            elsif( $lang eq 'js' ) {
                $copy .= "    this['$var'] = \$params['mod_$depname'] || 0;\n";
            }
        }
    }
    
    my $sys = ( $modname eq 'systemx' );
        
    my $out;
    if( $lang eq 'perl' ) {
        $out = $sys ? '' : "my \$SYS;\n";
        my $sysfetch = $sys ? '' : "\$SYS = \$params{'sys'};\n";
        <tpl append in=direct out=out>
            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                *{sysfetch}
                *{copy}
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &*{pkg}*{modname}::init ) && !$self->{'skipInit'} );
                return $self;
            }
        </tpl>
    }
    elsif( $lang eq 'js' ) {
        $out = '';
        my $sys_set = '';
        my $sysName = $pkgvar;
        $sysName =~ s/_$//;
        if( !$sys ) {
            #$out = "my \$SYS;\n";
            $sys_set = "this.SYS = \$params.sys;\n";
        }
        <tpl append in=direct out=out>
            function MOD_*{pkgvar}*{modname}( $params ) {
                *{sys_set}
                *{copy}
                this['_conf'] = $params.conf || 0;
                if( MOD_*{pkgvar}*{modname}.prototype.init && !this.skipInit ) this.init( $params );
            }
        </tpl>
        if( $sys ) {
            <tpl append>
                LumithModData.sysMods.*{sysName} = MOD_*{pkgvar}*{modname};
            </tpl>
        }
    }
    return $out;
}

sub tag_header {
    <param name="modXML" var="module" />
    <param name="metacode" var="node" />
    <param name="modInfo" var="modinfo" />
    
    my $modname = $module->{'name'};
    my $pkg = $mod_builder->{'pkg'};
    
    my $lang = $self->{'lang'};
    if( $lang eq 'perl' ) {
        my $output = "package $pkg$modname;\n";
        my $cpan = $module->{'_cpan'};
        for my $mod ( @$cpan ) {
            my $name = $mod->{'name'};
            my $qw = $mod->{'qw'};
            my $qwt = $qw ? "qw/$qw/" : "";
            $output .= "use $name $qwt;\n";
        }
        $output .= "use strict;\n";
        $output .= "use warnings;\n";
        return $output;
    }
    if( $lang eq 'js' ) {
        my $jspkg = $pkg;
        $jspkg =~ s/::/_/g;
        #my $output = "var MOD_$jspkg$modname = {};\n";
        #return $output;
        return '';
    }
}

sub tag_var {
    <param name="metacode" var="tag" />
    
    my $sub = $mod_builder->{'cursub'};
    my $vars = $sub->{'vars'};
    push( @$vars, $tag );
    return '';
}

sub tag_sysblock {
    <param name="modXML" var="module" />
    <param name="metacode" var="node" />
    <param name="modInfo" />
    my $lang = $self->{'lang'};
    if( $lang eq 'perl' ) {
        return $self->tag_sysblock_perl( modXML => $module, metacode => $node, modInfo => $modInfo );
    }
    if( $lang eq 'js' ) {
        return $self->tag_sysblock_js( modXML => $module, metacode => $node, modInfo => $modInfo );
    }
}

sub tag_sysblock_perl {
    <param name="modXML" var="module" />
    <param name="metacode" var="node" />
    <param name="modInfo" />
    my $lang = $self->{'lang'};
    my $pkg = $mod_builder->{'pkg'};
    # modhash
    my $modhash = $mod_builder->{'modhash'};
    my $mods = deepclone( $modhash );
    
    my $sysName = $mod_builder->{'name'};
    my $sysPkg = $mod_builder->{'pkg'};
    
    my $out = "\$self->{build_id} = '$mod_systemgen->{build_id}';\
    \$self->{name} = '$sysName';\
    \$self->{pkg} = '$sysPkg';\
    \$self->{g}={};\n";
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $out .= "require $pkg$modname;\n";
    }
    
    my %fulfilled;
    my @roundinfo;
    for( my $round = 0;$round<10;$round++ ) {
        #print "Round $round\n";
        my $modlist_for_round = [];
        for my $modname ( keys %$mods ) {
            next if( $fulfilled{ $modname } );
            my $mod = $mods->{ $modname };
            my $deps = $mod->{'deps'};
            my $all_fulfilled = 1;
            for my $depname ( keys %$deps ) {
                if( !$fulfilled{ $depname } ) {
                    $all_fulfilled = 0;
                    last;
                }
            }
            if( $all_fulfilled ) {
                push( @$modlist_for_round, $modname );
                #print "  Module $modname\n";
            }
        }
        for my $donemod ( @$modlist_for_round ) {
            $fulfilled{ $donemod } = 1;
        }
        if( !@$modlist_for_round ) {
            for my $modname ( keys %$mods ) {
                next if( $fulfilled{ $modname } );
                print "Unfulfilled mod $modname\n";
                my $mod = $mods->{ $modname };
                my $deps = $mod->{'deps'};
                for my $depname ( keys %$deps ) {
                    if( !$fulfilled{ $depname } ) {
                        print "  Missing $depname\n";
                    }
                }
            }
            last;
        }
        push( @roundinfo, $modlist_for_round );
    }
    $out .= "    my \$mods = \$self->{'mods'} = {};\n";
    $out .= $mod_builder->{'systemCreate'} || '';
    
    my $i=0;
    
    #print "Code generation\n";
    for my $round ( @roundinfo ) {
        $i++;
        #print "  round $i\n";
        $out .= "  # round $i\n";
        for my $modname ( @$round ) {
            #print "    Module $modname\n";
            my $mod = $mods->{ $modname };
            my $deps = $mod->{'deps'};
            if( $modname eq 'systemx' ) {
                $out .= "    \$mods->{'systemx'} = \$self;\n";
            }
            else {
                $out .= $self->output_conf( $modname );
                $out .= "    \$mods->{'$modname'} = $pkg$modname->new( sys => \$self, conf => \$confX_$modname,\n";
                if( $deps && %$deps ) {
                    for my $depname ( keys %$deps ) {
                        $out .= "    mod_$depname => \$mods->{'$depname'},\n";
                    }
                    #$out = substr( $out, 0, -2 ) . "\n";
                }
                
                my $imported_deps = $mod->{'imported_deps'};
                if( $imported_deps ) {
                    for my $impName ( keys %$imported_deps ) {
                        my $impHash = $imported_deps->{ $impName };
                        for my $impAs ( keys %$impHash ) {
                            if( $impAs !~ m/^mod_/ ) { $impAs = "mod_$impAs"; }
                            $out .= "    $impAs => \$importedModules->{'$impName'},\n";
                        }
                    }
                }
                
                $out .= "  );\n";
            }
        }
    }
    
    for my $modname ( keys %$mods ) {
        my $mod = $mods->{ $modname };
        #print Dumper( $mod );
        my $delayed_deps = $mod->{'delayed_deps'};
        if( $delayed_deps && %$delayed_deps ) {
            for my $dep ( keys %$delayed_deps ) {
                my $asvars = $delayed_deps->{ $dep };
                for my $asvar ( keys %$asvars ) {
                    $out .= "    \$mods->{'$modname'}{'$asvar'} = \$mods->{'$dep'};\n";
                }
            }
        }
    }
    
    my $mods_with_tags = $mod_builder->{'mods_with_tags'};
    if( $mods_with_tags ) {
        $out .= "    my \$tagsystem = \$_params{'tagsystem'};\
    if( \$tagsystem ) {\n";
        $out .= "      my \$lang = \$_params{'lang'} || 'perl';\n";
        for my $amod_with_tag ( @$mods_with_tags ) {
            $out .= "\$mods->{'$amod_with_tag'}->setup_tags( \$tagsystem, lang => \$lang ) if( \$mods->{'$amod_with_tag'} );\n";
        }
        $out .= "    }\n";
    }
    
    # scan through configurations, looking for dependencies
    
    my @quotedMods;
    for my $modname ( keys %$mods ) {
        push( @quotedMods, "'$modname'" );
    }
    my $modStr = join( ',', @quotedMods ); 
    
    my $confStr = '';
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $confStr .= "$modname => \$confX_$modname,\n";
    }
    $confStr = substr( $confStr, 0, -2 ); # remove last comma and CR
    
    my $hasConfStr = '';
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $hasConfStr .= "$modname => (defined( &$pkg::${modname}::conf )?1:0),\n";
    }
    $hasConfStr = substr( $hasConfStr, 0, -2 );
    
    $out .= "
    # Use conf dependency resolution if available
    if( \$mods->{'conf'} ) {
        \$mods->{'conf'}->doConf(
            modInstances => \$mods,
            mods => [ $modStr ],
            conf => {
                $confStr
            },
            hasConf => {
                $hasConfStr
            }
        );\
    }
    else {\n";
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $out .= "  if( defined( &$pkg::${modname}::conf ) ) { \$mods->{'$modname'}->conf( \$confX_$modname );\n }\n";
    }
    $out .= "}\n";
    
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $out .= "if( defined( &$pkg::${modname}::postconf ) ) { \$mods->{'$modname'}->postconf();\n }\n";
    }
    
    return $out;
}

sub tag_sysblock_js {
    <param name="modXML" var="module" />
    <param name="metacode" var="node" />
    <param name="modInfo" />
    
    my $pkg = $mod_builder->{'pkg'};
    my $pkgvar = $mod_builder->{'pkgvar'};
    # modhash
    my $modhash = $mod_builder->{'modhash'};
    my $mods = deepclone( $modhash );
    my $out = "this.build_id = '$mod_systemgen->{build_id}';\
    this.g = {};\n";
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        #$out .= "require $pkg$modname;\n";
    }
    
    my %fulfilled;
    my @roundinfo;
    for( my $round = 0;$round<10;$round++ ) {
        #print "Round $round\n";
        my $modlist_for_round = [];
        for my $modname ( keys %$mods ) {
            next if( $fulfilled{ $modname } );
            my $mod = $mods->{ $modname };
            my $deps = $mod->{'deps'};
            my $all_fulfilled = 1;
            for my $depname ( keys %$deps ) {
                if( !$fulfilled{ $depname } ) {
                    $all_fulfilled = 0;
                    last;
                }
            }
            if( $all_fulfilled ) {
                push( @$modlist_for_round, $modname );
                #print "  Module $modname\n";
            }
        }
        for my $donemod ( @$modlist_for_round ) {
            $fulfilled{ $donemod } = 1;
        }
        if( !@$modlist_for_round ) {
            for my $modname ( keys %$mods ) {
                next if( $fulfilled{ $modname } );
                print "Unfulfilled mod $modname\n";
                my $mod = $mods->{ $modname };
                my $deps = $mod->{'deps'};
                for my $depname ( keys %$deps ) {
                    if( !$fulfilled{ $depname } ) {
                        print "  Missing $depname\n";
                    }
                }
            }
            last;
        }
        push( @roundinfo, $modlist_for_round );
    }
    $out .= "    var mods = this.mods = {};\n";
    $out .= $mod_builder->{'systemCreate'} || '';
    
    my $i=0;
    
    #print "Code generation\n";
    for my $round ( @roundinfo ) {
        $i++;
        #print "  round $i\n";
        $out .= "  // round $i\n";
        for my $modname ( @$round ) {
            #print "    Module $modname\n";
            my $mod = $mods->{ $modname };
            my $deps = $mod->{'deps'};
            if( $modname eq 'systemx' ) {
                $out .= "    mods.systemx = this;\n";
            }
            else {
                $out .= $self->output_conf( $modname );
                $out .= "    mods['$modname'] = new MOD_$pkgvar$modname( { 'sys': this, 'conf': confX_$modname,\n";
                if( $deps && %$deps ) {
                    for my $depname ( keys %$deps ) {
                        $out .= "    'mod_$depname': mods.$depname,\n";
                    }
                    #$out = substr( $out, 0, -2 ) . "\n";
                }
                
                my $imported_deps = $mod->{'imported_deps'};
                if( $imported_deps ) {
                    for my $impName ( keys %$imported_deps ) {
                        my $impHash = $imported_deps->{ $impName };
                        for my $impAs ( keys %$impHash ) {
                            if( $impAs !~ m/^mod_/ ) { $impAs = "mod_$impAs"; }
                            $out .= "    '$impAs': importedModules.$impName,\n";
                        }
                    }
                }
                $out =~ s/,\s*$//;
                
                $out .= " } );\n";
            }
        }
    }
    
    for my $modname ( keys %$mods ) {
        my $mod = $mods->{ $modname };
        #print Dumper( $mod );
        my $delayed_deps = $mod->{'delayed_deps'};
        if( $delayed_deps && %$delayed_deps ) {
            for my $dep ( keys %$delayed_deps ) {
                my $asvars = $delayed_deps->{ $dep };
                for my $asvar ( keys %$asvars ) {
                    $out .= "    mods['$modname']['$asvar'] = mods['$dep'];\n";
                }
            }
        }
    }
    
    my $mods_with_tags = $mod_builder->{'mods_with_tags'};
    if( $mods_with_tags ) {
        $out .= "    var tagsystem = \$params['tagsystem'];\
    if( tagsystem ) {\n";    
        for my $amod_with_tag ( @$mods_with_tags ) {
            $out .= "if( mods['$amod_with_tag'] ) { mods['$amod_with_tag'].setup_tags( tagsystem ); }\n";
        }
        $out .= "    }\n";
    }
    
    # scan through configurations, looking for dependencies
    
    my @quotedMods;
    for my $modname ( keys %$mods ) {
        push( @quotedMods, "'$modname'" );
    }
    my $modStr = join( ',', @quotedMods ); 
    
    my $confStr = '';
    for my $modname ( keys %$mods ) {
        $confStr .= "$modname: confX_$modname,\n";
    }
    $confStr = substr( $confStr, 0, -2 ); # remove last comma and CR
    
    $out .= "
    # Use conf dependency resolution if available
    if( mods.conf ) {
        mods.conf.doConf( {
            modInstances: mods,
            mods: [ $modStr ],
            conf: {
                $confStr
            }
        } );\
    }
    else {\n";
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $out .= "  if( mods.$modname.conf ) { mods.$modname.conf( confX_$modname );\n }\n";
    }
    $out .= "}\n";
    
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );
        $out .= "  if( mods.$modname.postconf ) { mods.$modname.postconf();\n }\n";
    }
   
    return $out;
}

sub tag_tag {
    <param name="metacode" var="tag" />
    <param name="builder" />
    <param name="modInfo" />
    
    my $tagName = $tag->{'name'};
    
    my $curSub = $builder->{'cursub'};
    $modInfo->{'hasTags'} = 1;
    my $subName = $curSub->{'name'};
    my $stage = $tag->{'stage'} || 'normal';
    my $type = $tag->{'type'} || 'normal';
    my $alias = $tag->{'alias'} || '';
    my $aliasStr;
    my $lang = $self->{'lang'};
    
    #print "Registering tag $tagName\n";

    my $setup_tags_sub;
    my $setup_code;
    if( $lang eq 'perl' ) {
        $aliasStr = $alias ? ", alias => '$alias'" : '';
        <tpl append in=direct out=setup_tags_sub>
            sub setup_tags( tagsystem ) {
                <param name="lang"/>
                print 'Setting up tags from module '.__FILE__."\n";
                $self->{'lang'} = $lang || 'perl';
            }
        </tpl>
        <tpl append in=direct out=setup_code>
            $tagsystem->register_tag(
                name => '*{tagName}',
                func => \&*{subName},
                mod => $self,
                stage => '*{stage}',
                type => '*{type}'
                *{aliasStr}
            );
        </tpl>
    }
    if( $lang eq 'js' ) {
        $aliasStr = $alias ? ", 'alias': '$alias'" : '';
        <tpl append in=direct out=setup_tags_sub>
            sub setup_tags( tagsystem, lang ) {
                console.log( 'Setting up tags from module '.__FILE__." );\n";
            }
        </tpl>
        <tpl append in=direct out=setup_code>
            tagsystem.register_tag( {
                'name': '*{tagName}',
                'func': *{subName},
                'mod': $self,
                'stage': '*{stage}',
                'type': '*{type}'
                *{aliasStr}
            } );
        </tpl>
    }
    return [
        { action => 'add_sub', name => 'setup_tags', text => $setup_tags_sub },
        { action => 'add_sub_text', sub => 'setup_tags', text => $setup_code } ,
    ];
}

sub tag_param {
    <param name="metacode" var="tag" />
    
    my $name = $tag->{'name'};
    my $var = $tag->{'var'} || $name;
    
    my $lang = $self->{'lang'};
    if( $lang eq 'perl' ) {
        return "    my \$$var = \$_params{'$name'};\n";
    }
    if( $lang eq 'js' ) {
        return "    var $var = \$params['$name'];\n";
    }
}

sub tag_page {
    <param name="metacode" var="tag" />
    <param name="builder" />
    <param name="tagdata" />
    
    my $systemName = $builder->{'system_name'} or confess "System name is not set";
    my $pageName = $tag->{'name'};
    my $subName = $builder->{'cursub'}{'name'};
    
    my $curmodName = $mod_builder->{'curmod'}{'name'};
    my $pageMap = $tagdata->{'pageMap'} ||= {};
    my $newMap = { subName => $subName, modName => $curmodName };
    if( my $curMap = $pageMap->{$pageName} ) {
        if( ref( $curMap ) eq 'ARRAY' ) {
            push( @$curMap, $newMap );
        }
        else {
            $curMap = $pageMap->{$pageName} = [$curMap,$newMap];
        }
        print "Conflicting page routes:\n";
        my $i=0;
        for my $map ( @$curMap ) {
            $i++;
            my $mod = $map->{'modName'};
            my $sub = $map->{'subName'};
            print "  $i. Mod: $mod - Sub: $sub\n";
        }
    }
    else {
        $pageMap->{$pageName} = $newMap;
    }
    my $lang = $self->{'lang'};
    my $reg_code;
    if( $lang eq 'perl' ) {
        <tpl append in=direct out=reg_code>
            $mod_router->register( '*{systemName}', '*{pageName}', \&*{subName}, $self );
        </tpl>
    }
    if( $lang eq 'js' ) {
        <tpl append in=direct out=reg_code>
            mod_router.register( '*{systemName}', '*{pageName}', *{subName}, this );
        </tpl>
    }
    
    return [
        { action => 'add_var', self => 'mod_response', var => 'resp' },
        { action => 'add_mod', mod => 'router' },
        { action => 'add_mod', mod => 'response', delayed => 1 },
        { action => 'add_sub_var', sub => 'init', self => 'mod_router' },
        { action => 'add_sub_text', sub => 'init', text => $reg_code }
    ];
}

sub output_conf( modName ) {
    my $modhash = $mod_builder->{'modhash'};
    my $modinfo = $modhash->{ $modName };
    
    my $buildXML = $modinfo->{'buildXML'};
    my $constructConf = $modinfo->{'construct_conf'};
    #print "$modName construct:".Dumper( $constructConf );
    #print "$modName buildXML:".Dumper( $buildXML );
    my $modXML = filter_xml( $constructConf, $buildXML );
    #print "$modName filtered:".Dumper( $modXML );
    my $xmlText;
    my $confIsSet = 1;
    if( $modXML ) {
        $xmlText = XML::Bare::Object::xml( 0, $modXML );
    }
    else {
        $xmlText = '<empty/>';
        $confIsSet = 0;
    }
    if( $xmlText =~ m/^\s*$/ ) {
        $xmlText = "<empty/>";
        $confIsSet = 0;
    }    
    
    my $lang = $self->{'lang'};
    my $out;
    if( $lang eq 'perl' ) {
        <tpl append in=direct out=out>
            my $conf_*{modName};
            my $confX_*{modName} = {};
            # Imported conf comes through params
            if( $_params{'conf_*{modName}'} ) {
                $confX_*{modName} = $_params{'conf_*{modName}'};
            }
        </tpl>
        
        if( $confIsSet ) {
            <tpl append>
                if( ref( $confX_*{modName} ) ne 'ARRAY' ) { $confX_*{modName} = [ $confX_*{modName} ]; }
                my $conf_xml_*{modName} =<<'ENDEND';
*{xmlText}
ENDEND
                my ( $ob_*{modName}, $newConfX_*{modName} ) = XML::Bare->simple( text => $conf_xml_*{modName} );
                push( @{$confX_*{modName}}, $newConfX_*{modName} );
            </tpl>
        }
    }
    if( $lang eq 'js' ) {
        my $confJsa = xjr_to_jsa( $xmlText );
        <tpl append in=direct out=out>
            var confX_*{modName} = {};
            if( $params.conf_*{modName} ) {
                confX_*{modName} = $params.conf_*{modName};
            }
        </tpl>
        
        if( $confIsSet ) {
            <tpl append>
                if( ! confX_*{modName}.length ) { confX_*{modName} = [ confX_*{modName} ]; }
                var conf_jsa_*{modName} = *{''confJsa};
                var newConfX_*{modName} = JsaToDC( conf_jsa_*{modName} );
                confX_*{modName}.push( newConfX_*{modName} );
            </tpl>
        }
    }
    return $out;
}

psub deepclone {
    my $hash = shift;
    my $copy = {};
    for my $key ( keys %$hash ) {
        my $val = $hash->{ $key };
        my $reftype = ref( $val );
        if( $reftype ) {
            if( $reftype eq 'HASH' ) {
                $copy->{ $key } = deepclone( $val );
            }
            next;
        }
        $copy->{ $key } = $val;
    }
    return $copy;
}

psub filter_xml {
    my ( $filter, $data ) = @_;
    my $output = {};
    
    # If the data is just a plain value, go ahead and return it regardless of filter
    return $data if( !ref( $data ) );
    
    # If the filter is blank here, return an empty hash
    return {} if( !$filter );
    
    # If the filter is a string, check to see if it is the string 'PASS'; if so return data,
    #   otherwise return an empty hash ( a normal string value would have been passed already )
    if( !ref( $filter ) ) {
        if( $filter eq 'PASS' ) {
            return $data;
        }
        return {};
    }
    for my $key ( keys %$filter ) {
        my $dataval = $data->{ $key };
        if( ! defined $dataval ) {
            $output->{ $key } = $filter->{ $key };
        }
        else {
            $output->{ $key } = filter_xml( $filter->{ $key }, $dataval );
        }
    }
    return $output;
}