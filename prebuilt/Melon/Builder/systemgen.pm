package Melon::Builder::systemgen;
use Cwd qw/abs_path/;
use File::Slurp ;
use XML::Bare qw/forcearray/;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                    $self->{'mod_uuid'} = $params{'mod_uuid'} || 0;
    $self->{'mod_templates'} = $params{'mod_templates'} || 0;

                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::systemgen::init ) && !$self->{'skipInit'} );
                return $self;
            }use Parse::XJR;#@6
use XML::Bare qw/forcearray/;#@7
sub init { #@9
    my $self=shift;
  my %_params = @_;
    my $mod_uuid = $self->{'mod_uuid'};
    $self->{'build_id'} = $mod_uuid->new_id();#@10
    $self->{'lang'} = 'perl';#@11
}
sub setlang { #@14
    my $self=shift;
    my $lang = shift;
  my %_params = @_;
    $self->{'lang'} = $lang;#@15
}
sub get_info_filename { #@18
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $name = $mod_builder->{'name'};#@19
    return "systems/$name.xml";#@20
}
sub write_info_file { #@23
    my $self=shift;
    my $modhash = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $ns = $mod_builder->{'namespace'};#@24
    my $pkg = $mod_builder->{'pkg'};#@25
    my $name = $mod_builder->{'name'};#@26
    my $dir = $mod_builder->{'dir'};#@27
    my $path = "$dir/$ns/";#@28
    my $lang = $self->{'lang'};#@29
    $path = abs_path($path);#@31
    my $lib = "$dir/";#@32
    $lib = abs_path($lib);#@33
    my $modText = '';#@35
    for my $modName ( keys %$modhash ) {
        my $modInfo = $modhash->{ $modName };#@37
        my $hasTagText = $modInfo->{'hasTags'} ? 'hasTags=1' : '';#@38
        $modText .= "<mod name='$modName' $hasTagText/>\n";#@39
    }
    my $versionXML = $SYS->{g}{version_current}->getXML();#@42
    my $buildId = $self->{'build_id'};#@43
    my $jsdepText = '';#@45
    if( $lang eq 'js' ) {
        $jsdepText = XML::Bare::Object::xml( 0, { jsdep => $mod_builder->{'jsdep'} } );#@47
    }    
    my $cssText = '';#@50
    if( $lang eq 'js' ) {
        $cssText = XML::Bare::Object::xml( 0, { css => $mod_builder->{'css'} } );#@52
    }
my $info = '';
  $info .= ''."\n".'        <xml>'."\n".'            <build_id>';
  # XML: <var name='buildId'/> #@56
  $info .= $buildId;
  $info .= '</build_id>'."\n".'            <name>';
  # XML: <var name='name'/> #@57
  $info .= $name;
  $info .= '</name>'."\n".'            <package>';
  # XML: <var name='pkg'/> #@58
  $info .= $pkg;
  $info .= '</package>'."\n".'            <path>';
  # XML: <var name='path'/> #@59
  $info .= $path;
  $info .= '</path>'."\n".'            <lib>';
  # XML: <var name='lib'/> #@60
  $info .= $lib;
  $info .= '</lib>'."\n".'            <lang>';
  # XML: <var name='lang'/> #@61
  $info .= $lang;
  $info .= '</lang>'."\n".'            ';
  # XML: <var name='jsdepText'/> #@62
  $info .= $jsdepText;
  $info .= ''."\n".'            ';
  # XML: <var name='cssText'/> #@63
  $info .= $cssText;
  $info .= ''."\n".'            ';
  # XML: <var name='modText'/> #@64
  $info .= $modText;
  $info .= ''."\n".'            ';
  # XML: <var name='versionXML'/> #@65
  $info .= $versionXML;
  $info .= ''."\n".'        </xml>';#@56
    write_file( "systems/$name.xml", $info );#@70
    if( $self->{'lang'} eq 'js' ) {
        my $jsa = xjr_to_jsa( $info );#@72
        $jsa =~ s/'/"/g;#@73
        write_file( "systems/$name.jsa", $jsa );#@74
    }
}
sub load_systems { #@78
    my $self=shift;
    my $systems = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $mod_tagsystem = $self->{'mod_tagsystem'};
    my $mod_templates = $self->{'mod_templates'};
    my $lang = $self->{'lang'};#@79
    my $systemsR = $mod_builder->{'systems'} = {};#@81
    my $importedModules = $mod_builder->{'importedModules'} = {};#@83
    my $systemCreate;#@84
    if( $lang eq 'perl' ) {
        $systemCreate = "my \$systems = \$self->{'systems'} = {};\n";#@86
        $systemCreate .= "my \$importedModules = \$self->{'importedModules'} = {};\n";#@87
    }
    if( $lang eq 'js' ) {
        $systemCreate = "var systems = this.systems = {};\n";#@90
        $systemCreate .= "var importedModules = this.importedModules = {};\n";#@91
    }
    for my $system ( @$systems ) {
        my $sysName = $system->{'name'};#@95
        my $sysLang = $system->{'lang'} || 'perl';#@96
        my $file = $system->{'file'};#@97
        next if( $systemsR->{ $sysName } );#@99
        print "Loading system info file $file\n";#@101
        my ( $ob, $systemInfo ) = XML::Bare->simple( file => $file );#@102
        $systemInfo = $systemInfo->{'xml'};#@103
        $SYS->{g}{version_current}->trackUsedSystem( $sysName, ( $systemInfo->{'build_id'} || '?' ), $sysLang, $systemInfo->{'name'} );#@105
        my $modInfoSet = forcearray( $systemInfo->{'mod'} );#@106
        my %modInfoHash;#@107
        my @tagMods;#@108
        for my $mod ( @$modInfoSet ) {
            my $modName = $mod->{'name'};#@110
            if( $mod->{'hasTags'} ) {
                push( @tagMods, $modName );#@112
            }
            $modInfoHash{ $modName } = $mod;#@114
        }
        my $path = $systemInfo->{'path'};#@117
        my $package = $systemInfo->{'package'};#@118
        my $lib = $systemInfo->{'lib'};#@119
        my $sys = 0;#@121
        if( $sysLang eq 'perl' ) {
            my $pmFile = "${path}/systemx.pm";#@125
            my $short = substr($package,0,-2)."::systemx";#@128
            $self->unload_module($short);#@129
            if( $package =~ m/Core2/ ) {
                $self->unload_module("Melon::Core::systemx");#@131
            }
            require $pmFile or die "Could not load pm file $pmFile";#@134
            $sys = "${package}systemx"->new( builder => $mod_builder, tagsystem => $mod_tagsystem, lang => $lang );#@135
            $systemsR->{ $sysName } = $sys;#@136
        }
        my $confs = forcearray( $system->{'conf'} );#@140
        my $modConfs = '';#@141
        my %confdone;#@142
        if( $lang eq 'perl' ) {
            for my $conf ( @$confs ) {
                my $modName = $conf->{'mod'};#@145
                $confdone{ $modName } = 1;#@146
                my $xmlText = XML::Bare::Object::xml( 0, { xml => $conf } );#@147
  $systemCreate .= ''."\n".'                    my $';
  # XML: <var name='sysName'/> #@149
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@149
  $systemCreate .= $modName;
  $systemCreate .= '_conf_xml = <<\'ENDEND\';'."\n".'                    ';
  # XML: <var name='xmlText'/> #@149
  $systemCreate .= $xmlText;
  $systemCreate .= ''."\n".'ENDEND'."\n".'                    my ( $';
  # XML: <var name='sysName'/> #@151
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@151
  $systemCreate .= $modName;
  $systemCreate .= '_ob, $';
  # XML: <var name='sysName'/> #@151
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@151
  $systemCreate .= $modName;
  $systemCreate .= '_conf ) = XML::Bare->simple( text => $';
  # XML: <var name='sysName'/> #@151
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@151
  $systemCreate .= $modName;
  $systemCreate .= '_conf_xml );'."\n".'                    $';
  # XML: <var name='sysName'/> #@152
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@152
  $systemCreate .= $modName;
  $systemCreate .= '_conf = $';
  # XML: <var name='sysName'/> #@152
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@152
  $systemCreate .= $modName;
  $systemCreate .= '_conf->{\'xml\'};'."\n".'                    '."\n".'                    if( $_params{\'conf_';
  # XML: <var name='modName'/> #@154
  $systemCreate .= $modName;
  $systemCreate .= '\'} ) {'."\n".'                        my $curConf = $_params{\'conf_';
  # XML: <var name='modName'/> #@155
  $systemCreate .= $modName;
  $systemCreate .= '\'};'."\n".'                        if( ref( $curConf ) ne \'ARRAY\' ) { $curConf = [ $curConf ]; }'."\n".'                        $';
  # XML: <var name='sysName'/> #@157
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@157
  $systemCreate .= $modName;
  $systemCreate .= '_conf = [ @$curConf, $';
  # XML: <var name='sysName'/> #@157
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@157
  $systemCreate .= $modName;
  $systemCreate .= '_conf ];'."\n".'                    }';#@149
                $modConfs .= "conf_${modName} => \$${sysName}_${modName}_conf,\n";#@162
            }
        }
        if( $sysLang eq 'js' && $lang eq 'js' ) {
            for my $conf ( @$confs ) {
                my $modName = $conf->{'mod'};#@167
                $confdone{ $modName } = 1;#@168
                my $confJsa = xjr_to_jsa( $conf );#@169
  $systemCreate .= ''."\n".'                    var ';
  # XML: <var name='sysName'/> #@171
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@171
  $systemCreate .= $modName;
  $systemCreate .= '_conf_jsa = ';
  # XML: <varq name='confJsa'/> #@171
  $systemCreate .= $mod_templates->escape( $confJsa );
  $systemCreate .= ';'."\n".'                    var ';
  # XML: <var name='sysName'/> #@171
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@171
  $systemCreate .= $modName;
  $systemCreate .= '_conf = JsaToDC( ';
  # XML: <var name='sysName'/> #@171
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@171
  $systemCreate .= $modName;
  $systemCreate .= '_conf_jsa );'."\n".'                    '."\n".'                    if( $params.conf_';
  # XML: <var name='modName'/> #@173
  $systemCreate .= $modName;
  $systemCreate .= ' ) {'."\n".'                        var curConf = $params.conf_';
  # XML: <var name='modName'/> #@174
  $systemCreate .= $modName;
  $systemCreate .= ';'."\n".'                        if( !$curConf.length ) { curConf = [ curConf ]; }'."\n".'                        ';
  # XML: <var name='sysName'/> #@176
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@176
  $systemCreate .= $modName;
  $systemCreate .= '_conf = [ curConf, ';
  # XML: <var name='sysName'/> #@176
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@176
  $systemCreate .= $modName;
  $systemCreate .= '_conf ];'."\n".'                    }';#@171
                $modConfs .= "conf_${modName}: ${sysName}_${modName}_conf,\n";#@181
            }
        }
        my $imports = forcearray( $system->{'import'} );#@185
        for my $import ( @$imports ) {
            my $modName = $import->{'mod'};#@187
            if( !$confdone{ $modName } ) {
                if( $lang eq 'perl' ) {
  $systemCreate .= ''."\n".'                        my $';
  # XML: <var name='sysName'/> #@191
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@191
  $systemCreate .= $modName;
  $systemCreate .= '_conf = {};'."\n".'                        if( $_params{\'conf_';
  # XML: <var name='modName'/> #@191
  $systemCreate .= $modName;
  $systemCreate .= '\'} ) {'."\n".'                            $';
  # XML: <var name='sysName'/> #@192
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@192
  $systemCreate .= $modName;
  $systemCreate .= '_conf = $_params{\'conf_';
  # XML: <var name='modName'/> #@192
  $systemCreate .= $modName;
  $systemCreate .= '\'};'."\n".'                        }';#@191
                }
                if( $sysLang eq 'js' && $lang eq 'js' ) {
  $systemCreate .= ''."\n".'                        var ';
  # XML: <var name='sysName'/> #@199
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@199
  $systemCreate .= $modName;
  $systemCreate .= '_conf = {};'."\n".'                        if( $params.conf_';
  # XML: <var name='modName'/> #@199
  $systemCreate .= $modName;
  $systemCreate .= ' ) {'."\n".'                            ';
  # XML: <var name='sysName'/> #@200
  $systemCreate .= $sysName;
  $systemCreate .= '_';
  # XML: <var name='modName'/> #@200
  $systemCreate .= $modName;
  $systemCreate .= '_conf = $params.conf_';
  # XML: <var name='modName'/> #@200
  $systemCreate .= $modName;
  $systemCreate .= ';'."\n".'                        }';#@199
                }
            }
        }
        if( $lang eq 'perl' ) {
  $systemCreate .= ''."\n".'                #my $';
  # XML: <var name='sysName'/> #@213
  $systemCreate .= $sysName;
  $systemCreate .= 'modules = $systems->{';
  # XML: <varq name='sysName'/> #@213
  $systemCreate .= $mod_templates->escape( $sysName );
  $systemCreate .= '} = {};'."\n".'                {'."\n".'                    no warnings \'redefine\';'."\n".'                    require ';
  # XML: <var name='package'/> #@215
  $systemCreate .= $package;
  $systemCreate .= 'systemx;'."\n".'                }'."\n".'                my $system_';
  # XML: <var name='sysName'/> #@217
  $systemCreate .= $sysName;
  $systemCreate .= ' = $systems->{';
  # XML: <varq name='sysName'/> #@217
  $systemCreate .= $mod_templates->escape( $sysName );
  $systemCreate .= '} = "';
  # XML: <var name='package'/> #@217
  $systemCreate .= $package;
  $systemCreate .= 'systemx"->new('."\n".'                    tagsystem => $_params{\'tagsystem\'},'."\n".'                    lang => ( $_params{\'lang\'} || \'perl\' ),'."\n".'                    ';
  # XML: <var name='modConfs'/> #@220
  $systemCreate .= $modConfs;
  $systemCreate .= ''."\n".'                );';#@213
        }
        if( $sysLang eq 'js' && $lang eq 'js' ) {
            my $pkgvar = $package;#@226
            $pkgvar =~ s/::/_/g;#@227
            my $sysNameCap = $systemInfo->{'name'};#@228
  $systemCreate .= ''."\n".'                var ';
  # XML: <var name='sysName'/> #@230
  $systemCreate .= $sysName;
  $systemCreate .= 'modules = systems[';
  # XML: <varq name='sysName'/> #@230
  $systemCreate .= $mod_templates->escape( $sysName );
  $systemCreate .= '] = {};'."\n".'                // require ';
  # XML: <var name='pkgvar'/> #@230
  $systemCreate .= $pkgvar;
  $systemCreate .= 'systemx;'."\n".'                var system_';
  # XML: <var name='sysName'/> #@231
  $systemCreate .= $sysName;
  $systemCreate .= ' = new MOD_';
  # XML: <var name='pkgvar'/> #@231
  $systemCreate .= $pkgvar;
  $systemCreate .= 'systemx( {'."\n".'                    tagsystem: $params.tagsystem,'."\n".'                    ';
  # XML: <var name='modConfs'/> #@233
  $systemCreate .= $modConfs;
  $systemCreate .= ''."\n".'                } );'."\n".'                var loader = $params.loader;'."\n".'                if( loader ) loader.setSystemInst( ';
  # XML: <varq name='sysNameCap'/> #@236
  $systemCreate .= $mod_templates->escape( $sysNameCap );
  $systemCreate .= ', system_';
  # XML: <var name='sysName'/> #@236
  $systemCreate .= $sysName;
  $systemCreate .= ' );';#@230
        }
        for my $import ( @$imports ) {
            my $modName = $import->{'mod'};#@243
            $importedModules->{ $modName } = 1;#$mod;#@245
            if( $lang eq 'perl' ) {
                $systemCreate .= "\$importedModules->{'$modName'} = \$system_$sysName->getmod('$modName');\n";#@249
                $systemCreate .= "\$mods->{'$modName'} = \$system_$sysName->getmod('$modName');\n";#@250
            }
            if( $sysLang eq 'js' && $lang eq 'js' ) {
                $systemCreate .= "importedModules.$modName = system_$sysName.getmod('$modName');\n";#@254
                $systemCreate .= "mods.$modName = system_$sysName.getmod('$modName');\n";#@255
            }
        }
        if( $sysLang eq 'perl' && $lang eq 'perl' ) {
            if( @tagMods ) {
                my @mods_with_tags;#@261
                for my $tagModName ( @tagMods ) {
                    my $tagmod = $sys->getmod($tagModName);#@264
                    if( $tagmod ) {
                        my $setup = "${package}${tagModName}::setup_tags";#@268
                        if( defined( &$setup ) ) {
                            push( @mods_with_tags, $tagModName );#@270
                            $tagmod->setup_tags( $mod_tagsystem, lang => $lang );#@271
                        }
                    }
                }
                if( @mods_with_tags ) {
                    $mod_builder->{'mods_with_tags'} = \@mods_with_tags;#@276
                }
            }
        }
    }
    $mod_builder->{'systemCreate'} = $systemCreate;#@281
}
sub unload_module { #@284
    my $self=shift;
    my $ns = shift;
  my %_params = @_;
    no strict 'refs';#@285
    my @subs = keys %{"$ns\::"};#@286
    if( @subs ) {
    }
    for my $sub ( @subs ) {
        my $sym = "$ns\::$sub";#@291
        eval { undef &$sym };#@293
        warn "$sym: $@" if $@;#@294
    }
}

1;
