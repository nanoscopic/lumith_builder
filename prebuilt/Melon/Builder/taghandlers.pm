package Melon::Builder::taghandlers;
use Data::Dumper ;
use Carp ;
use XML::Bare qw/forcearray/;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                    $self->{'mod_templates'} = $params{'mod_templates'} || 0;

                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::taghandlers::init ) && !$self->{'skipInit'} );
                return $self;
            }use Parse::XJR;#@5
sub init { #@7
    my $self=shift;
  my %_params = @_;
    $self->{'lang'} = 'perl';#@8
}
sub setlang { #@11
    my $self=shift;
    my $lang = shift;
  my %_params = @_;
    $self->{'lang'} = $lang;#@12
}
sub setup_stages { #@15
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
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
    ];#@48
    return $stages;#@49
}
sub tag_new_inst { #@52
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $node = $_params{'metacode'};#@53
    my $modinfo = $_params{'modInfo'};#@54
    my $modname = $modinfo->{'name'};#@56
    my $pkg = $mod_builder->{'pkg'};#@57
    my $lang = $self->{'lang'};#@59
    my $out;#@61
    if( $lang eq 'perl' ) {
  $out .= ''."\n".'            my $root = shift;'."\n".'            my $class = ref( $root );'."\n".'            my %params = @_;'."\n".'            my $self = bless { %$root }, $class;'."\n".'            '."\n".'            $self->init_inst(%params) if( defined( &';
  # XML: <var name='pkg'/> #@68
  $out .= $pkg;
  # XML: <var name='modname'/> #@68
  $out .= $modname;
  $out .= '::init_inst ) && !$self->{\'skipInit\'} );'."\n".'            return $self;';#@64
    }
    if( $lang eq 'js' ) {
        my $pkgvar = $mod_builder->{'pkgvar'};#@74
  $out .= ''."\n".'            function MOD_';
  # XML: <var name='pkgvar'/> #@76
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@76
  $out .= $modname;
  $out .= '_inst( $params ) {'."\n".'                if( MOD_';
  # XML: <var name='pkgvar'/> #@76
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@76
  $out .= $modname;
  $out .= '.prototype.init_inst ) this.init_inst( $params );'."\n".'            }'."\n".'            MOD_';
  # XML: <var name='pkgvar'/> #@78
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@78
  $out .= $modname;
  $out .= '.prototype.new_inst = function( $params ) {'."\n".'                return new MOD_';
  # XML: <var name='pkgvar'/> #@79
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@79
  $out .= $modname;
  $out .= '_inst( $params );'."\n".'            }';#@76
my $init = '';
  $init .= ''."\n".'            MOD_';
  # XML: <var name='pkgvar'/> #@85
  $init .= $pkgvar;
  # XML: <var name='modname'/> #@85
  $init .= $modname;
  $init .= '_inst.prototype = this;';#@85
        return [
            { action => 'add_text', text => $out },
            { action => 'add_sub_text', sub => 'init', text => $init }
        ];#@91
    }
    return $out;#@93
}
sub tag_construct { #@96
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $module = $_params{'modXML'};#@97
    my $node = $_params{'metacode'};#@98
    my $modinfo = $_params{'modInfo'};#@99
    my $builder = $_params{'builder'};#@100
    my $conf = $node->{'conf'} || {};#@102
    $modinfo->{'construct_conf'} = $conf;#@103
    if( !$node || !ref( $node ) ) {
        $node = {};#@106
    }
    my $mods = $node->{'mod'} ? forcearray( $node->{'mod'} ) : [];#@108
    my %modByName;#@109
    for my $mod ( @$mods ) {
        my $modName = $mod->{'name'};#@111
        $modByName{ $modName } = $mod;#@112
    }
    my $pkg = $mod_builder->{'pkg'};#@115
    my $pkgvar = $mod_builder->{'pkgvar'};#@116
    my $importedModules = $mod_builder->{'importedModules'};#@117
    my $taghash = $builder->{'taghash'};#@119
    my $constructHash = $taghash->{'construct'} || {};#@120
    my $modulesFromHash = $constructHash->{'modules'} || {};#@121
    for my $extraModName ( keys %$modulesFromHash ) {
        my $extraMod = $modulesFromHash->{ $extraModName };#@124
        next if( $modByName{ $extraModName } );#@126
        $modByName{ $extraModName } = {
            name => $extraModName,
            var => ( $extraMod->{'var'} || "mod_$extraModName" ),
            delayed => $extraMod->{'delayed'}
        };#@131
    }
    my $modname = $modinfo->{'name'};#@134
    my $copy = "";#@138
    my $deps;#@142
    my $delayed_deps;#@143
    my $imported_deps;#@144
    if( ! ( $deps = $modinfo->{'deps'} ) ) {
        $deps = $modinfo->{'deps'} = {};#@146
    }
    if( ! ( $delayed_deps = $modinfo->{'delayed_deps'} ) ) {
        $delayed_deps = $modinfo->{'delayed_deps'} = {};#@149
    }
    if( ! ( $imported_deps = $modinfo->{'imported_deps'} ) ) {
        $imported_deps = $modinfo->{'imported_deps'} = {};#@152
    }
    for my $modName ( keys %modByName ) {
        my $mod = $modByName{ $modName };#@156
        my $delayed = $mod->{'delayed'};#@158
        my $var = $mod->{'var'} || "mod_$modName";#@159
        if( $importedModules->{ $modName } ) {
            $imported_deps->{ $modName } ||= {};#@161
            $imported_deps->{ $modName }{ $var } = 1;#@162
            next;#@163
        }
        if( $delayed ) {
            $delayed_deps->{ $modName } ||= {};#@166
            $delayed_deps->{ $modName }{ $var } = 1;#@167
            next;#@168
        }
        $deps->{ $modName } ||= {};#@171
        $deps->{ $modName }{ $var } = 1;#@172
    }
    my $lang = $self->{'lang'};#@176
    for my $depname ( keys %$deps ) {
        for my $var ( keys %{$deps->{$depname}} ) {
            if( $lang eq 'perl' ) {
                $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";#@182
            }
            elsif( $lang eq 'js' ) {
                $copy .= "    this['$var'] = \$params['mod_$depname'] || 0;\n";#@185
            }
        }
    }
    for my $depname ( keys %$imported_deps ) {
        for my $var ( keys %{$imported_deps->{$depname}} ) {
            if( $lang eq 'perl' ) {
                $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";#@194
            }
            elsif( $lang eq 'js' ) {
                $copy .= "    this['$var'] = \$params['mod_$depname'] || 0;\n";#@197
            }
        }
    }
    my $sys = ( $modname eq 'systemx' );#@202
    my $out;#@204
    if( $lang eq 'perl' ) {
        $out = $sys ? '' : "my \$SYS;\n";#@206
        my $sysfetch = $sys ? '' : "\$SYS = \$params{'sys'};\n";#@207
  $out .= ''."\n".'            sub new {'."\n".'                my $class = shift;'."\n".'                my %params = @_;'."\n".'                my $self = bless {}, $class;'."\n".'                ';
  # XML: <var name='sysfetch'/> #@212
  $out .= $sysfetch;
  $out .= ''."\n".'                ';
  # XML: <var name='copy'/> #@213
  $out .= $copy;
  $out .= ''."\n".'                $self->{\'_conf\'} = $params{\'conf\'} || 0;'."\n".'                $self->init(%params) if( defined( &';
  # XML: <var name='pkg'/> #@215
  $out .= $pkg;
  # XML: <var name='modname'/> #@215
  $out .= $modname;
  $out .= '::init ) && !$self->{\'skipInit\'} );'."\n".'                return $self;'."\n".'            }';#@209
    }
    elsif( $lang eq 'js' ) {
        $out = '';#@222
        my $sys_set = '';#@223
        my $sysName = $pkgvar;#@224
        $sysName =~ s/_$//;#@225
        if( !$sys ) {
            $sys_set = "this.SYS = \$params.sys;\n";#@228
        }
  $out .= ''."\n".'            function MOD_';
  # XML: <var name='pkgvar'/> #@231
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@231
  $out .= $modname;
  $out .= '( $params ) {'."\n".'                ';
  # XML: <var name='sys_set'/> #@231
  $out .= $sys_set;
  $out .= ''."\n".'                ';
  # XML: <var name='copy'/> #@232
  $out .= $copy;
  $out .= ''."\n".'                this[\'_conf\'] = $params.conf || 0;'."\n".'                if( MOD_';
  # XML: <var name='pkgvar'/> #@234
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@234
  $out .= $modname;
  $out .= '.prototype.init && !this.skipInit ) this.init( $params );'."\n".'            }';#@231
        if( $sys ) {
  $out .= ''."\n".'                LumithModData.sysMods.';
  # XML: <var name='sysName'/> #@240
  $out .= $sysName;
  $out .= ' = MOD_';
  # XML: <var name='pkgvar'/> #@240
  $out .= $pkgvar;
  # XML: <var name='modname'/> #@240
  $out .= $modname;
  $out .= ';';#@240
        }
    }
    return $out;#@244
}
sub tag_header { #@247
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $module = $_params{'modXML'};#@248
    my $node = $_params{'metacode'};#@249
    my $modinfo = $_params{'modInfo'};#@250
    my $modname = $module->{'name'};#@252
    my $pkg = $mod_builder->{'pkg'};#@253
    my $lang = $self->{'lang'};#@255
    if( $lang eq 'perl' ) {
        my $output = "package $pkg$modname;\n";#@257
        my $cpan = $module->{'_cpan'};#@258
        for my $mod ( @$cpan ) {
            my $name = $mod->{'name'};#@260
            my $qw = $mod->{'qw'};#@261
            my $qwt = $qw ? "qw/$qw/" : "";#@262
            $output .= "use $name $qwt;\n";#@263
        }
        $output .= "use strict;\n";#@265
        $output .= "use warnings;\n";#@266
        return $output;#@267
    }
    if( $lang eq 'js' ) {
        my $jspkg = $pkg;#@270
        $jspkg =~ s/::/_/g;#@271
        return '';#@274
    }
}
sub tag_var { #@278
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $tag = $_params{'metacode'};#@279
    my $sub = $mod_builder->{'cursub'};#@281
    my $vars = $sub->{'vars'};#@282
    push( @$vars, $tag );#@283
    return '';#@284
}
sub tag_sysblock { #@287
    my $self=shift;
  my %_params = @_;
    my $module = $_params{'modXML'};#@288
    my $node = $_params{'metacode'};#@289
    my $modInfo = $_params{'modInfo'};#@290
    my $lang = $self->{'lang'};#@291
    if( $lang eq 'perl' ) {
        return $self->tag_sysblock_perl( modXML => $module, metacode => $node, modInfo => $modInfo );#@293
    }
    if( $lang eq 'js' ) {
        return $self->tag_sysblock_js( modXML => $module, metacode => $node, modInfo => $modInfo );#@296
    }
}
sub tag_sysblock_perl { #@300
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $mod_systemgen = $self->{'mod_systemgen'};
    my $module = $_params{'modXML'};#@301
    my $node = $_params{'metacode'};#@302
    my $modInfo = $_params{'modInfo'};#@303
    my $lang = $self->{'lang'};#@304
    my $pkg = $mod_builder->{'pkg'};#@305
    my $modhash = $mod_builder->{'modhash'};#@307
    my $mods = deepclone( $modhash );#@308
    my $sysName = $mod_builder->{'name'};#@310
    my $sysPkg = $mod_builder->{'pkg'};#@311
    my $out = "\$self->{build_id} = '$mod_systemgen->{build_id}';\
    \$self->{name} = '$sysName';\
    \$self->{pkg} = '$sysPkg';\
    \$self->{g}={};\n";#@316
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@318
        $out .= "require $pkg$modname;\n";#@319
    }
    my %fulfilled;#@322
    my @roundinfo;#@323
    for( my $round = 0;$round<10;$round++ ) {
        my $modlist_for_round = [];#@326
        for my $modname ( keys %$mods ) {
            next if( $fulfilled{ $modname } );#@328
            my $mod = $mods->{ $modname };#@329
            my $deps = $mod->{'deps'};#@330
            my $all_fulfilled = 1;#@331
            for my $depname ( keys %$deps ) {
                if( !$fulfilled{ $depname } ) {
                    $all_fulfilled = 0;#@334
                    last;#@335
                }
            }
            if( $all_fulfilled ) {
                push( @$modlist_for_round, $modname );#@339
            }
        }
        for my $donemod ( @$modlist_for_round ) {
            $fulfilled{ $donemod } = 1;#@344
        }
        if( !@$modlist_for_round ) {
            for my $modname ( keys %$mods ) {
                next if( $fulfilled{ $modname } );#@348
                print "Unfulfilled mod $modname\n";#@349
                my $mod = $mods->{ $modname };#@350
                my $deps = $mod->{'deps'};#@351
                for my $depname ( keys %$deps ) {
                    if( !$fulfilled{ $depname } ) {
                        print "  Missing $depname\n";#@354
                    }
                }
            }
            last;#@358
        }
        push( @roundinfo, $modlist_for_round );#@360
    }
    $out .= "    my \$mods = \$self->{'mods'} = {};\n";#@362
    $out .= $mod_builder->{'systemCreate'} || '';#@363
    my $i=0;#@365
    for my $round ( @roundinfo ) {
        $i++;#@369
        $out .= "  # round $i\n";#@371
        for my $modname ( @$round ) {
            my $mod = $mods->{ $modname };#@374
            my $deps = $mod->{'deps'};#@375
            if( $modname eq 'systemx' ) {
                $out .= "    \$mods->{'systemx'} = \$self;\n";#@377
            }
            else {
                $out .= $self->output_conf( $modname );#@380
                $out .= "    \$mods->{'$modname'} = $pkg$modname->new( sys => \$self, conf => \$confX_$modname,\n";#@381
                if( $deps && %$deps ) {
                    for my $depname ( keys %$deps ) {
                        $out .= "    mod_$depname => \$mods->{'$depname'},\n";#@384
                    }
                }
                my $imported_deps = $mod->{'imported_deps'};#@389
                if( $imported_deps ) {
                    for my $impName ( keys %$imported_deps ) {
                        my $impHash = $imported_deps->{ $impName };#@392
                        for my $impAs ( keys %$impHash ) {
                            if( $impAs !~ m/^mod_/ ) { $impAs = "mod_$impAs"; }
                            $out .= "    $impAs => \$importedModules->{'$impName'},\n";#@395
                        }
                    }
                }
                $out .= "  );\n";#@400
            }
        }
    }
    for my $modname ( keys %$mods ) {
        my $mod = $mods->{ $modname };#@406
        my $delayed_deps = $mod->{'delayed_deps'};#@408
        if( $delayed_deps && %$delayed_deps ) {
            for my $dep ( keys %$delayed_deps ) {
                my $asvars = $delayed_deps->{ $dep };#@411
                for my $asvar ( keys %$asvars ) {
                    $out .= "    \$mods->{'$modname'}{'$asvar'} = \$mods->{'$dep'};\n";#@413
                }
            }
        }
    }
    my $mods_with_tags = $mod_builder->{'mods_with_tags'};#@419
    if( $mods_with_tags ) {
        $out .= "    my \$tagsystem = \$_params{'tagsystem'};\
    if( \$tagsystem ) {\n";#@422
        $out .= "      my \$lang = \$_params{'lang'} || 'perl';\n";#@423
        for my $amod_with_tag ( @$mods_with_tags ) {
            $out .= "\$mods->{'$amod_with_tag'}->setup_tags( \$tagsystem, lang => \$lang ) if( \$mods->{'$amod_with_tag'} );\n";#@425
        }
        $out .= "    }\n";#@427
    }
    my @quotedMods;#@432
    for my $modname ( keys %$mods ) {
        push( @quotedMods, "'$modname'" );#@434
    }
    my $modStr = join( ',', @quotedMods ); 
    my $confStr = '';#@438
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@440
        $confStr .= "$modname => \$confX_$modname,\n";#@441
    }
    $confStr = substr( $confStr, 0, -2 ); # remove last comma and CR
    my $hasConfStr = '';#@445
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@447
        $hasConfStr .= "$modname => (defined( &$pkg::${modname}::conf )?1:0),\n";#@448
    }
    $hasConfStr = substr( $hasConfStr, 0, -2 );#@450
    $out .= "
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
    else {\n";#@466
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@468
        $out .= "  if( defined( &$pkg::${modname}::conf ) ) { \$mods->{'$modname'}->conf( \$confX_$modname );\n }\n";#@469
    }
    $out .= "}\n";#@471
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@474
        $out .= "if( defined( &$pkg::${modname}::postconf ) ) { \$mods->{'$modname'}->postconf();\n }\n";#@475
    }
    return $out;#@478
}
sub tag_sysblock_js { #@481
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $mod_systemgen = $self->{'mod_systemgen'};
    my $module = $_params{'modXML'};#@482
    my $node = $_params{'metacode'};#@483
    my $modInfo = $_params{'modInfo'};#@484
    my $pkg = $mod_builder->{'pkg'};#@486
    my $pkgvar = $mod_builder->{'pkgvar'};#@487
    my $modhash = $mod_builder->{'modhash'};#@489
    my $mods = deepclone( $modhash );#@490
    my $out = "this.build_id = '$mod_systemgen->{build_id}';\
    this.g = {};\n";#@492
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@494
    }
    my %fulfilled;#@498
    my @roundinfo;#@499
    for( my $round = 0;$round<10;$round++ ) {
        my $modlist_for_round = [];#@502
        for my $modname ( keys %$mods ) {
            next if( $fulfilled{ $modname } );#@504
            my $mod = $mods->{ $modname };#@505
            my $deps = $mod->{'deps'};#@506
            my $all_fulfilled = 1;#@507
            for my $depname ( keys %$deps ) {
                if( !$fulfilled{ $depname } ) {
                    $all_fulfilled = 0;#@510
                    last;#@511
                }
            }
            if( $all_fulfilled ) {
                push( @$modlist_for_round, $modname );#@515
            }
        }
        for my $donemod ( @$modlist_for_round ) {
            $fulfilled{ $donemod } = 1;#@520
        }
        if( !@$modlist_for_round ) {
            for my $modname ( keys %$mods ) {
                next if( $fulfilled{ $modname } );#@524
                print "Unfulfilled mod $modname\n";#@525
                my $mod = $mods->{ $modname };#@526
                my $deps = $mod->{'deps'};#@527
                for my $depname ( keys %$deps ) {
                    if( !$fulfilled{ $depname } ) {
                        print "  Missing $depname\n";#@530
                    }
                }
            }
            last;#@534
        }
        push( @roundinfo, $modlist_for_round );#@536
    }
    $out .= "    var mods = this.mods = {};\n";#@538
    $out .= $mod_builder->{'systemCreate'} || '';#@539
    my $i=0;#@541
    for my $round ( @roundinfo ) {
        $i++;#@545
        $out .= "  // round $i\n";#@547
        for my $modname ( @$round ) {
            my $mod = $mods->{ $modname };#@550
            my $deps = $mod->{'deps'};#@551
            if( $modname eq 'systemx' ) {
                $out .= "    mods.systemx = this;\n";#@553
            }
            else {
                $out .= $self->output_conf( $modname );#@556
                $out .= "    mods['$modname'] = new MOD_$pkgvar$modname( { 'sys': this, 'conf': confX_$modname,\n";#@557
                if( $deps && %$deps ) {
                    for my $depname ( keys %$deps ) {
                        $out .= "    'mod_$depname': mods.$depname,\n";#@560
                    }
                }
                my $imported_deps = $mod->{'imported_deps'};#@565
                if( $imported_deps ) {
                    for my $impName ( keys %$imported_deps ) {
                        my $impHash = $imported_deps->{ $impName };#@568
                        for my $impAs ( keys %$impHash ) {
                            if( $impAs !~ m/^mod_/ ) { $impAs = "mod_$impAs"; }
                            $out .= "    '$impAs': importedModules.$impName,\n";#@571
                        }
                    }
                }
                $out =~ s/,\s*$//;#@575
                $out .= " } );\n";#@577
            }
        }
    }
    for my $modname ( keys %$mods ) {
        my $mod = $mods->{ $modname };#@583
        my $delayed_deps = $mod->{'delayed_deps'};#@585
        if( $delayed_deps && %$delayed_deps ) {
            for my $dep ( keys %$delayed_deps ) {
                my $asvars = $delayed_deps->{ $dep };#@588
                for my $asvar ( keys %$asvars ) {
                    $out .= "    mods['$modname']['$asvar'] = mods['$dep'];\n";#@590
                }
            }
        }
    }
    my $mods_with_tags = $mod_builder->{'mods_with_tags'};#@596
    if( $mods_with_tags ) {
        $out .= "    var tagsystem = \$params['tagsystem'];\
    if( tagsystem ) {\n";    
        for my $amod_with_tag ( @$mods_with_tags ) {
            $out .= "if( mods['$amod_with_tag'] ) { mods['$amod_with_tag'].setup_tags( tagsystem ); }\n";#@601
        }
        $out .= "    }\n";#@603
    }
    my @quotedMods;#@608
    for my $modname ( keys %$mods ) {
        push( @quotedMods, "'$modname'" );#@610
    }
    my $modStr = join( ',', @quotedMods ); 
    my $confStr = '';#@614
    for my $modname ( keys %$mods ) {
        $confStr .= "$modname: confX_$modname,\n";#@616
    }
    $confStr = substr( $confStr, 0, -2 ); # remove last comma and CR
    $out .= "
    if( mods.conf ) {
        mods.conf.doConf( {
            modInstances: mods,
            mods: [ $modStr ],
            conf: {
                $confStr
            }
        } );\
    }
    else {\n";#@631
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@633
        $out .= "  if( mods.$modname.conf ) { mods.$modname.conf( confX_$modname );\n }\n";#@634
    }
    $out .= "}\n";#@636
    for my $modname ( keys %$mods ) {
        next if( $modname eq 'systemx' );#@639
        $out .= "  if( mods.$modname.postconf ) { mods.$modname.postconf();\n }\n";#@640
    }
    return $out;#@643
}
sub tag_tag { #@646
    my $self=shift;
  my %_params = @_;
    my $tag = $_params{'metacode'};#@647
    my $builder = $_params{'builder'};#@648
    my $modInfo = $_params{'modInfo'};#@649
    my $tagName = $tag->{'name'};#@651
    my $curSub = $builder->{'cursub'};#@653
    $modInfo->{'hasTags'} = 1;#@654
    my $subName = $curSub->{'name'};#@655
    my $stage = $tag->{'stage'} || 'normal';#@656
    my $type = $tag->{'type'} || 'normal';#@657
    my $alias = $tag->{'alias'} || '';#@658
    my $aliasStr;#@659
    my $lang = $self->{'lang'};#@660
    my $setup_tags_sub;#@664
    my $setup_code;#@665
    if( $lang eq 'perl' ) {
        $aliasStr = $alias ? ", alias => '$alias'" : '';#@667
  $setup_tags_sub .= ''."\n".'            sub setup_tags( tagsystem ) {'."\n".'                <param name="lang"/>'."\n".'                print \'Setting up tags from module \'.__FILE__."\\n";'."\n".'                $self->{\'lang\'} = $lang || \'perl\';'."\n".'            }';#@669
  $setup_code .= ''."\n".'            $tagsystem->register_tag('."\n".'                name => \'';
  # XML: <var name='tagName'/> #@676
  $setup_code .= $tagName;
  $setup_code .= '\','."\n".'                func => \\&';
  # XML: <var name='subName'/> #@677
  $setup_code .= $subName;
  $setup_code .= ','."\n".'                mod => $self,'."\n".'                stage => \'';
  # XML: <var name='stage'/> #@679
  $setup_code .= $stage;
  $setup_code .= '\','."\n".'                type => \'';
  # XML: <var name='type'/> #@680
  $setup_code .= $type;
  $setup_code .= '\''."\n".'                ';
  # XML: <var name='aliasStr'/> #@681
  $setup_code .= $aliasStr;
  $setup_code .= ''."\n".'            );';#@676
    }
    if( $lang eq 'js' ) {
        $aliasStr = $alias ? ", 'alias': '$alias'" : '';#@687
  $setup_tags_sub .= ''."\n".'            sub setup_tags( tagsystem, lang ) {'."\n".'                console.log( \'Setting up tags from module \'.__FILE__." );\\n";'."\n".'            }';#@689
  $setup_code .= ''."\n".'            tagsystem.register_tag( {'."\n".'                \'name\': \'';
  # XML: <var name='tagName'/> #@694
  $setup_code .= $tagName;
  $setup_code .= '\','."\n".'                \'func\': ';
  # XML: <var name='subName'/> #@695
  $setup_code .= $subName;
  $setup_code .= ','."\n".'                \'mod\': $self,'."\n".'                \'stage\': \'';
  # XML: <var name='stage'/> #@697
  $setup_code .= $stage;
  $setup_code .= '\','."\n".'                \'type\': \'';
  # XML: <var name='type'/> #@698
  $setup_code .= $type;
  $setup_code .= '\''."\n".'                ';
  # XML: <var name='aliasStr'/> #@699
  $setup_code .= $aliasStr;
  $setup_code .= ''."\n".'            } );';#@694
    }
    return [
        { action => 'add_sub', name => 'setup_tags', text => $setup_tags_sub },
        { action => 'add_sub_text', sub => 'setup_tags', text => $setup_code } ,
    ];#@707
}
sub tag_param { #@710
    my $self=shift;
  my %_params = @_;
    my $tag = $_params{'metacode'};#@711
    my $name = $tag->{'name'};#@713
    my $var = $tag->{'var'} || $name;#@714
    my $lang = $self->{'lang'};#@716
    if( $lang eq 'perl' ) {
        return "    my \$$var = \$_params{'$name'};\n";#@718
    }
    if( $lang eq 'js' ) {
        return "    var $var = \$params['$name'];\n";#@721
    }
}
sub tag_page { #@725
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $mod_router = $self->{'mod_router'};
    my $tag = $_params{'metacode'};#@726
    my $builder = $_params{'builder'};#@727
    my $tagdata = $_params{'tagdata'};#@728
    my $systemName = $builder->{'system_name'} or confess "System name is not set";#@730
    my $pageName = $tag->{'name'};#@731
    my $subName = $builder->{'cursub'}{'name'};#@732
    my $curmodName = $mod_builder->{'curmod'}{'name'};#@734
    my $pageMap = $tagdata->{'pageMap'} ||= {};#@735
    my $newMap = { subName => $subName, modName => $curmodName };#@736
    if( my $curMap = $pageMap->{$pageName} ) {
        if( ref( $curMap ) eq 'ARRAY' ) {
            push( @$curMap, $newMap );#@739
        }
        else {
            $curMap = $pageMap->{$pageName} = [$curMap,$newMap];#@742
        }
        print "Conflicting page routes:\n";#@744
        my $i=0;#@745
        for my $map ( @$curMap ) {
            $i++;#@747
            my $mod = $map->{'modName'};#@748
            my $sub = $map->{'subName'};#@749
            print "  $i. Mod: $mod - Sub: $sub\n";#@750
        }
    }
    else {
        $pageMap->{$pageName} = $newMap;#@754
    }
    my $lang = $self->{'lang'};#@756
    my $reg_code;#@757
    if( $lang eq 'perl' ) {
  $reg_code .= ''."\n".'            $mod_router->register( \'';
  # XML: <var name='systemName'/> #@760
  $reg_code .= $systemName;
  $reg_code .= '\', \'';
  # XML: <var name='pageName'/> #@760
  $reg_code .= $pageName;
  $reg_code .= '\', \\&';
  # XML: <var name='subName'/> #@760
  $reg_code .= $subName;
  $reg_code .= ', $self );';#@760
    }
    if( $lang eq 'js' ) {
  $reg_code .= ''."\n".'            mod_router.register( \'';
  # XML: <var name='systemName'/> #@765
  $reg_code .= $systemName;
  $reg_code .= '\', \'';
  # XML: <var name='pageName'/> #@765
  $reg_code .= $pageName;
  $reg_code .= '\', ';
  # XML: <var name='subName'/> #@765
  $reg_code .= $subName;
  $reg_code .= ', this );';#@765
    }
    return [
        { action => 'add_var', self => 'mod_response', var => 'resp' },
        { action => 'add_mod', mod => 'router' },
        { action => 'add_mod', mod => 'response', delayed => 1 },
        { action => 'add_sub_var', sub => 'init', self => 'mod_router' },
        { action => 'add_sub_text', sub => 'init', text => $reg_code }
    ];#@775
}
sub output_conf { #@778
    my $self=shift;
    my $modName = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $mod_templates = $self->{'mod_templates'};
    my $modhash = $mod_builder->{'modhash'};#@779
    my $modinfo = $modhash->{ $modName };#@780
    my $buildXML = $modinfo->{'buildXML'};#@782
    my $constructConf = $modinfo->{'construct_conf'};#@783
    my $modXML = filter_xml( $constructConf, $buildXML );#@786
    my $xmlText;#@788
    my $confIsSet = 1;#@789
    if( $modXML ) {
        $xmlText = XML::Bare::Object::xml( 0, $modXML );#@791
    }
    else {
        $xmlText = '<empty/>';#@794
        $confIsSet = 0;#@795
    }
    if( $xmlText =~ m/^\s*$/ ) {
        $xmlText = "<empty/>";#@798
        $confIsSet = 0;#@799
    }    
    my $lang = $self->{'lang'};#@802
    my $out;#@803
    if( $lang eq 'perl' ) {
  $out .= ''."\n".'            my $conf_';
  # XML: <var name='modName'/> #@806
  $out .= $modName;
  $out .= ';'."\n".'            my $confX_';
  # XML: <var name='modName'/> #@806
  $out .= $modName;
  $out .= ' = {};'."\n".'            # Imported conf comes through params'."\n".'            if( $_params{\'conf_';
  # XML: <var name='modName'/> #@808
  $out .= $modName;
  $out .= '\'} ) {'."\n".'                $confX_';
  # XML: <var name='modName'/> #@809
  $out .= $modName;
  $out .= ' = $_params{\'conf_';
  # XML: <var name='modName'/> #@809
  $out .= $modName;
  $out .= '\'};'."\n".'            }';#@806
        if( $confIsSet ) {
  $out .= ''."\n".'                if( ref( $confX_';
  # XML: <var name='modName'/> #@816
  $out .= $modName;
  $out .= ' ) ne \'ARRAY\' ) { $confX_';
  # XML: <var name='modName'/> #@816
  $out .= $modName;
  $out .= ' = [ $confX_';
  # XML: <var name='modName'/> #@816
  $out .= $modName;
  $out .= ' ]; }'."\n".'                my $conf_xml_';
  # XML: <var name='modName'/> #@816
  $out .= $modName;
  $out .= ' =<<\'ENDEND\';'."\n";
  # XML: <var name='xmlText'/> #@817
  $out .= $xmlText;
  $out .= ''."\n".'ENDEND'."\n".'                my ( $ob_';
  # XML: <var name='modName'/> #@819
  $out .= $modName;
  $out .= ', $newConfX_';
  # XML: <var name='modName'/> #@819
  $out .= $modName;
  $out .= ' ) = XML::Bare->simple( text => $conf_xml_';
  # XML: <var name='modName'/> #@819
  $out .= $modName;
  $out .= ' );'."\n".'                push( @{$confX_';
  # XML: <var name='modName'/> #@820
  $out .= $modName;
  $out .= '}, $newConfX_';
  # XML: <var name='modName'/> #@820
  $out .= $modName;
  $out .= ' );';#@816
        }
    }
    if( $lang eq 'js' ) {
        my $confJsa = xjr_to_jsa( $xmlText );#@826
  $out .= ''."\n".'            var confX_';
  # XML: <var name='modName'/> #@828
  $out .= $modName;
  $out .= ' = {};'."\n".'            if( $params.conf_';
  # XML: <var name='modName'/> #@828
  $out .= $modName;
  $out .= ' ) {'."\n".'                confX_';
  # XML: <var name='modName'/> #@829
  $out .= $modName;
  $out .= ' = $params.conf_';
  # XML: <var name='modName'/> #@829
  $out .= $modName;
  $out .= ';'."\n".'            }';#@828
        if( $confIsSet ) {
  $out .= ''."\n".'                if( ! confX_';
  # XML: <var name='modName'/> #@836
  $out .= $modName;
  $out .= '.length ) { confX_';
  # XML: <var name='modName'/> #@836
  $out .= $modName;
  $out .= ' = [ confX_';
  # XML: <var name='modName'/> #@836
  $out .= $modName;
  $out .= ' ]; }'."\n".'                var conf_jsa_';
  # XML: <var name='modName'/> #@836
  $out .= $modName;
  $out .= ' = ';
  # XML: <varq name='confJsa'/> #@836
  $out .= $mod_templates->escape( $confJsa );
  $out .= ';'."\n".'                var newConfX_';
  # XML: <var name='modName'/> #@837
  $out .= $modName;
  $out .= ' = JsaToDC( conf_jsa_';
  # XML: <var name='modName'/> #@837
  $out .= $modName;
  $out .= ' );'."\n".'                confX_';
  # XML: <var name='modName'/> #@838
  $out .= $modName;
  $out .= '.push( newConfX_';
  # XML: <var name='modName'/> #@838
  $out .= $modName;
  $out .= ' );';#@836
        }
    }
    return $out;#@843
}
sub deepclone {
    my $hash = shift;#@847
    my $copy = {};#@848
    for my $key ( keys %$hash ) {
        my $val = $hash->{ $key };#@850
        my $reftype = ref( $val );#@851
        if( $reftype ) {
            if( $reftype eq 'HASH' ) {
                $copy->{ $key } = deepclone( $val );#@854
            }
            next;#@856
        }
        $copy->{ $key } = $val;#@858
    }
    return $copy;#@860
}
sub filter_xml {
    my ( $filter, $data ) = @_;#@864
    my $output = {};#@865
    return $data if( !ref( $data ) );#@868
    return {} if( !$filter );#@871
    if( !ref( $filter ) ) {
        if( $filter eq 'PASS' ) {
            return $data;#@877
        }
        return {};#@879
    }
    for my $key ( keys %$filter ) {
        my $dataval = $data->{ $key };#@882
        if( ! defined $dataval ) {
            $output->{ $key } = $filter->{ $key };#@884
        }
        else {
            $output->{ $key } = filter_xml( $filter->{ $key }, $dataval );#@887
        }
    }
    return $output;#@890
}

1;
