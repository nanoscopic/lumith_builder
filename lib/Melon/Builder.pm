# Copyright (C) 2018 David Helkowski

package Melon::Builder;

use strict;
use warnings;
use XML::Bare qw/xval forcearray/;
use File::Slurp;
use Data::Dumper;
use Cwd qw/abs_path/;
use lib q|/home/user/lumith_builder/built|;
use Carp;

sub new {
    my $class = shift;
    my %params = @_;
    my $self = bless \%params, $class;
    
    my ( $ob, $xml ) = XML::Bare->simple( file => $self->{'file'} );
    $xml = $self->{'xml'} = $xml->{'xml'};
    
    # Let direct parameter take precedence
    # After that use parameter in XML file
    # Finally just use a default value
    my $ns = $self->{'namespace'} || $xml->{'namespace'} || 'Melon/Default';
    $self->{'namespace'} = $ns;
    
    my $name = $self->{'name'};
    if( !$name && $xml->{'name'} ) {
        $name = $xml->{'name'};
    }
    $self->{'system_name'} = $name;
    
    if( ! -e "built/$ns" ) {
        my @parts = split( '/', $ns );
        my $curpath = 'built';
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
    
    return $self;
}

sub parse_xml_parts {
    my $parts = shift;
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
        #$x1->{'_key'} = get_first_key( $x1 );
    }
    return $hasXmlPart;
}

sub get_first_key {
    my $hash = shift;
    for my $key ( keys %$hash ) {
        next if( $key =~ m/^_/ );
        return $key;
    }
    return '';
}

sub setup_tag_stages {
    my $self = shift;
    my $raw_tags = $self->{'raw_tags'} = {};
    my $stages = $self->{'tag_stages'} = [
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
    
    my $stage_hash = $self->{'stage_hash'} = {};
    for my $stage ( @$stages ) {
        my $name = $stage->{'name'};
        $stage_hash->{ $name } = $stage;
    }
    
    return $stages;
}

sub build_module {
    my ( $self, $module ) = @_;
    my $module_build_res = $self->{'module_build_result'} = {};
    my $taghash = $self->{'taghash'} = {};
    my $modhash = $self->{'modhash'};
    $self->{'curmod'} = $module;
    my $modname = $module->{'name'};
    print "\n===== Processing module $modname =====\n";
    my %modinfo = ( name => $modname, buildXML => $module );
    $modhash->{ $modname } = \%modinfo;
    my $file = $module->{'file'};
    #print "\nProcessing $file\n";
    $module->{'_cpan'} = forcearray( $module->{'cpan'} );
    
    my $data = read_file( $file );
    my @lines = split(/\n/, $data);
    my $parts = $self->split_lines_to_parts( \@lines );
    parse_xml_parts( $parts );
    
    $self->{'subhash'} = {};
    my $subs = $self->{'subs'} = $self->split_parts_to_subs( $parts );
    my $subhash = $self->{'subhash'};
    #print Dumper( $subhash );
    my $output = "";
    
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
                
                for my $part ( @$subParts ) {
                    next if( $part->{'type'} ne 'line' );
                    my $part = $part->{'text'};
                    my %usedMods;
                    while( $part =~ m/\$mod_([a-zA-Z0-9_]+)/g ) {
                        $usedMods{$1} = ( $subName eq 'init' ) ? 'normal' : 'delayed';
                    }
                    for my $modName ( keys %usedMods ) {
                        my $depType = $usedMods{ $modName };
                        # Add the dependency so it is used within the construct tag
                        my $construct = $taghash->{'construct'} ||= {};
                        my $modules = $construct->{'modules'} ||= {};
                        if( !$modules->{ $modName } ) {
                            if( $depType eq 'delayed' ) {
                                $modules->{ $modName } = { delayed => 1, var => "mod_$modName" };
                            }
                            else {
                                $modules->{ $modName } = { var => "mod_$modName" };
                            }
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
            $self->{'curSub'} = $cursub;
            $cursub->{'parts'} = $self->process_xml_parts( $module, \%modinfo, $cursub->{'parts'} );
        }
    }
    #print " ===Stages Finished===\n";
    
    
    # "final stage" - all xml reduced already
    for my $cursub ( @$subs ) {
        $self->{'curSub'} = $cursub;
        my $subName  = $cursub->{'name'};
        my $subParts = $cursub->{'parts'};
        
        my $subOutput = '';
        for my $part ( @$subParts ) {
            my $type = $part->{'type'};
            if( $type eq 'xml' ) {
                print Dumper( $part );
                die "xml parts still present in final stage";
            }
            if( $type eq 'sub' ) {
                my $name = $part->{'name'};
                $self->start_sub();
                next;
            }
            if( $type eq 'line' ) {
                $subOutput .= $part->{'text'};
            }
        }
          
        #print "curSub: " . Dumper( $cursub );
        if( $cursub->{'type'} ne 'init' ) {
            my $subStart = $self->run_sub( modXml => $module, metacode => $cursub, modInfo => \%modinfo );
            #print "subStart: " . Dumper( $subStart );
            $subOutput = "sub $subName {\n" . $subStart . $subOutput;
        }
                    
        $output .= $subOutput;
    }
    
    my $ns = $self->{'namespace'};
    
    $output .= "\n1;\n";
    write_file( "built/$ns/$modname.pm", $output );
    
    return $module_build_res;
}

sub parse_args {
    my $cmdArgs = shift;
    my $argLine = join( ' ', @$cmdArgs );
    my $res = {};
    $argLine =~ s/--([a-zA-Z0-9_]+)/op_flag($1)/ge; # find and replace flags to have a value
    $argLine =~ s/--([a-zA-Z0-9_]+) ([^" ]+)/op_space($1,$2)/ge; # fix space delimited arguments
    
    #print "Argument line: $argLine\n";
    $argLine =~ s/--([a-zA-Z0-9_]+)="(.+?)"/named_arg($res,$1,$2)/ge;
    return $res;
}

sub named_arg {
    my ( $res, $name, $val ) = @_;
    if( $name eq 'skipmod' ) {
        my $skip = $res->{'skipModules'} ||= [];
        push( @$skip, $val );
    }
    return '';
}

sub op_flag {
    my $name = shift;
    my %flags = (
        );
    if( $flags{$name} ) {
        return "--$name=\"1\"";
    }
    return "--$name";
}

sub op_space {
    my ( $name, $val ) = @_;
    return "--$name=\"$val\"";
}

sub build {
    my $self = shift;
    my %parms = @_;
    
    my $xml = $self->{'xml'};
    
    $self->setup_tag_stages();
    
    if( $xml->{'system'} ) {
        my $systems = forcearray( $xml->{'system'} );
        $self->load_systems( $systems );
    }
    
    $self->{'modhash'} = {};
    
    my %skipHash;
    if( my $skipModules = $parms{'skipModules'} ) {
        for my $skipMod ( @$skipModules ) {
            print "Will skip module '$skipMod'\n";
            $skipHash{ $skipMod } = 1;
        }
    }
    
    my $modules = forcearray( $xml->{'module'} );
    while( @$modules ) {
        my $module = shift @$modules;
        my $modName = $module->{'name'};
        next if( $skipHash{ $modName } );
        my $res = $self->build_module( $module );
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
        
    $self->write_info_file( $self->{'modhash'} );
}

sub process_xml_parts {
    my ( $self, $module, $modinfo, $subParts ) = @_;
    
    my $tags = $self->{'curTags'};
    my $cursub = $self->{'curSub'};
    my $subName  = $cursub->{'name'};
    my $taghash = $self->{'taghash'};
    my $subhash = $self->{'subhash'};
    my $module_build_result = $self->{'module_build_result'};
    
    #print Dumper( $subParts );
    my $partsOut = [];
    for my $part ( @$subParts ) {
        next if( !$part );
        if( $part->{'type'} ne 'xml' ) {
            push( @$partsOut, $part );
            next;
        }
        #my $key = $part->{'xml'}{'_key'};
        my $key = get_first_key( $part->{'xml'} );
        if( !$key ) {
            print "No valid first key: ".Dumper($part);
        }
        #print Dumper( $part );
        #print "  tag $key\n";
        if( $tags->{$key} ) { # only process tags that are in this stage
            my $actions = $self->process_tag( $module, $part->{'xml'}, $modinfo );
            
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
                    if( $action eq 'add_mod' ) {
                        my $construct = $taghash->{'construct'} ||= {};
                        my $modules = $construct->{'modules'} ||= {};
                        my $new_module = $actionNode->{'mod'};
                        $modules->{ $new_module } = {
                            delayed => ( $actionNode->{'delayed'} || 0 ),
                            var => ( $actionNode->{'var'} || '' )
                        };
                    }
                    elsif( $action eq 'add_var' ) {
                        my $vars = $cursub->{'vars'};
                        my $as = $actionNode->{'var'} || '';
                        push( @$vars, { self => $actionNode->{'self'}, var => $as } );
                    }
                    elsif( $action eq 'add_sub_var' ) {
                        my $subNameToAddTo = $actionNode->{'sub'};
                        my $subToAddTo = $subhash->{$subNameToAddTo};
                        my $vars = $subToAddTo->{'vars'};
                        my $as = $actionNode->{'var'} || '';
                        push( @$vars, { self => $actionNode->{'self'}, var => $as } );
                    }
                    elsif( $action eq 'add_sub_text' ) {
                        my $subNameToAddTo = $actionNode->{'sub'};
                        my @lines = split(/\n/, $actionNode->{'text'});
                        my $newParts = $self->split_lines_to_parts( \@lines );
                        $newParts = $self->process_xml_parts( $module, $modinfo, $newParts );
                        
                        my $subToAddTo = $subhash->{$subNameToAddTo};
                        my $subparts = $subToAddTo->{'parts'};
                        cut_ending_paran( $subparts );
                        push( @$subparts, @$newParts, { type => 'line', text => "}\n" } );
                    }
                    elsif( $action eq 'add_text' ) {
                        my @lines = split(/\n/, $actionNode->{'text'});
                        my $newParts = $self->split_lines_to_parts( \@lines );
                        parse_xml_parts( $newParts );
                        $newParts = $self->process_xml_parts( $module, $modinfo, $newParts );
                        #print "New parts: ".Dumper( $newParts );
                        my $moreXml = parse_xml_parts( $newParts );
                        if( $moreXml ) {
                            $newParts = $self->process_xml_parts( $module, $modinfo, $newParts );
                        }
                        #print "After xml parse: ".Dumper( $newParts );
                        $part = $newParts;
                    }
                    elsif( $action eq 'add_sub' ) {
                        my $subToAdd = $actionNode->{'name'};
                        if( !$subhash->{ $subToAdd } ) {
                            #print "  Adding sub named $subToAdd\n";
                            my @lines = split(/\n/, $actionNode->{'text'});
                            my $newParts = $self->split_lines_to_parts( \@lines );
                            parse_xml_parts( $newParts );
                            my $newSubs = $self->split_parts_to_subs( $newParts );
                            my $subs = $self->{'subs'};
                            shift @$newSubs; # delete the 'init' sub
                            push( @$subs, @$newSubs );
                        }
                        else {
                            #print "  Skipping sub named $subToAdd\n";
                        }
                    }
                    elsif( $action eq 'create_module' ) {
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
                            file => $newFile
                        };
                        if( $actionNode->{'multiple'} ) {
                            $newConf->{'multiple'} = 1;
                        }
                        push( @$new_modules, $newConf );
                    }
                }
                
                if( ref( $part ) eq 'ARRAY' ) {
                    push( @$partsOut, @$part );
                }
                else {
                    $part->{'type'} = 'line';
                    $part->{'text'} = '';
                    push( @$partsOut, $part );
                }
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

sub cut_ending_paran {
    my $parts = shift;
    my $i = 0;
    my $ok = 0;
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

sub split_parts_to_subs {
    my ( $self, $parts ) = @_;
    
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
            $curparts = [ $part ];
            $cursub = { type => 'sub', name => $newSubName, parts => $curparts, vars => $part->{'vars'}, params => $part->{'params'} };
            $subhash->{ $newSubName } = $cursub;
            next;
        }
        push( @$curparts, $part );
    }
    push( @subs, $cursub );
    
    return \@subs;
}

sub start_sub {
    my $self = shift;
    # Run through the registered systems and call start_sub
}

sub write_info_file {
    my ( $self, $modhash ) = @_;
    
    my $ns = $self->{'namespace'};
    my $pkg = $self->{'pkg'};
    my $name = $self->{'name'};
    my $path = "./built/$ns/";
    $path = abs_path($path);
    my $lib = "./built/";
    $lib = abs_path($lib);
    
    my $modText = '';
    for my $modName ( keys %$modhash ) {
        my $modInfo = $modhash->{ $modName };
        my $hasTagText = $modInfo->{'hasTags'} ? 'hasTags=1' : '';
        $modText .= "<mod name='$modName' $hasTagText/>\n";
    }
    
    my $info = "<xml>
    <name>$name</name>
    <package>$pkg</package>
    <path>$path</path>
    <lib>$lib</lib>
    $modText
        
</xml>";
    write_file( "systems/$name.xml", $info );
}

sub register_tag {
    my $self = shift;
    my %parm = @_;
    my $tagname = $parm{'name'};
    my $func = $parm{'func'};
    my $mod = $parm{'mod'};
    my $stageName = $parm{'stage'};
    my $type = $parm{'type'} || 'normal';
    my $aliasP = $parm{'alias'} || 0;
    
    #print "Register tag: ".Dumper( \%parm );
    
    if( !$stageName ) {
        die "Stage must be specified when registering a tag";
    }
    my $stageHash = $self->{'stage_hash'};
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
                $self->{'raw_tags'}{ $alias } = 1;
            }
        }
    }
    
    if( $type eq 'raw' ) {
        $self->{'raw_tags'}{ $tagname } = 1;
    }
}

sub load_systems {
    my ( $self, $systems ) = @_;
    my $systemsR = $self->{'systems'} = {};
    
    my $importedModules = $self->{'importedModules'} = {};
    my $systemCreate = "my \$systems = \$self->{'systems'} = {};\n";
    $systemCreate .= "my \$importedModules = \$self->{'importedModules'} = {};\n";
    
    for my $system ( @$systems ) {
        my $sysName = $system->{'name'};
        my $file = $system->{'file'};
        
        next if( $systemsR->{ $sysName } );
        
        my ( $ob, $systemInfo ) = XML::Bare->simple( file => $file );
        $systemInfo = $systemInfo->{'xml'};
        
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
        
        # System is loaded within the builder so that any tags it has can be used
        # Problematically any configuration that system has is being ignored here. TODO
        my $pmFile = "${path}/systemx.pm";
        require $pmFile or die "Could not load pm file $pmFile";
        my $sys = "${package}systemx"->new( builder => $self );
        $systemsR->{ $sysName } = $sys;
        
        my $confs = forcearray( $system->{'conf'} );
        my $modConfs = '';
        for my $conf ( @$confs ) {
            my $modName = $conf->{'mod'};
            my $xmlText = XML::Bare::Object::xml( 0, { xml => $conf } );
            $systemCreate .= "
                my \$${sysName}_${modName}_conf_xml = <<'ENDEND';
                $xmlText
ENDEND
                my \$${sysName}_${modName}_conf = XML::Bare->new( text => \$${sysName}_${modName}_conf_xml );
                \$${sysName}_${modName}_conf = \$${sysName}_${modName}_conf->{'xml'};
            ";
            $modConfs .= "conf_${modName} => \$${sysName}_${modName}_conf,\n";
        }
        
        $systemCreate .= "
            my \$${sysName}modules = \$systems->{'$sysName'} = {};
            use lib '$lib';
            require \"${path}/systemx.pm\";
            my \$system_$sysName = \"${package}systemx\"->new( skipInit => 1 );
            \$system_$sysName->init(
            $modConfs);
        ";
        
        my $imports = forcearray( $system->{'import'} );
        for my $import ( @$imports ) {
            my $modName = $import->{'mod'};
            #my $mod = $sys->getmod( $modName );
            $importedModules->{ $modName } = 1;#$mod;
            
            #$systemCreate .= "\$${sysName}modules->{'$modName'} = \$system_$name->getmod('$modName');\n";
            $systemCreate .= "\$importedModules->{'$modName'} = \$system_$sysName->getmod('$modName');\n";
            $systemCreate .= "\$mods->{'$modName'} = \$system_$sysName->getmod('$modName');\n";
        }
        
        if( @tagMods ) {
            my @mods_with_tags;
            for my $tagModName ( @tagMods ) {
                print "Loading tags for build use from '$tagModName'\n";
                my $tagmod = $sys->getmod($tagModName);
                if( $tagmod ) {
                    #$self->init(%params) if( defined( &systemx::init ) );
                    
                    my $setup = "${package}${tagModName}::setup_tags";
                    if( defined( &$setup ) ) {
                        push( @mods_with_tags, $tagModName );
                        $tagmod->setup_tags( $self );
                    }
                }
            }
            if( @mods_with_tags ) {
                $self->{'mods_with_tags'} = \@mods_with_tags;
            }
        }
    }
    $self->{'systemCreate'} = $systemCreate;
}

sub split_lines_to_parts {
    my ( $self, $lines ) = @_;
    
    my $incomment = 0;
    my $commentxml = '';
    my @parts;
    my $tagname = '';
    
    my $mode = "normal";
    
    my $raw_tags = $self->{'raw_tags'};
    
    while( @$lines ) {
        my $line = shift @$lines;
        if( $mode eq 'normal' ) {
            if( $line =~ m/^`(.+)/ ) { # raw line
                push( @parts, { type => 'line', text => "$1\n" } );
                next;
            }
            if( $line =~ m|^\s*<!--.+-->\s*$| ) { # xml style comment
                next;
            }
            if( $line =~ m|^\s*(<.+/>)$| ) { # self closing xml
                push( @parts, { type => 'xml', xmlText => "$1" } );
                next;
            }
            if( $line =~ m|^\s*<([a-zA-Z_]+)| ) { # start of XML block
                $tagname = $1;
                if( $line =~ m|</$tagname>\s*$| ) { # closing tag on the same line
                    push( @parts, { type => 'xml', xmlText => "$line" } );
                    next;
                }
                if( $raw_tags->{ $tagname } ) {
                    #print "Start of raw tag $tagname\n";
                    $commentxml = "$line<raw><![CDATA[";
                    $mode = 'rawtag';
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
            if( $line =~ m/^\s*sub ([a-zA-Z0-9_-]+)\s*(\(\s*[a-zA-Z0-9_-]+\s*(,\s*[a-zA-Z0-9_-]+)*\s*\))?\s*\{\s*$/ ) {
                my $sub = $1;
                my $paramStr = $2;
                #print "paramsStr: " . Dumper( $paramStr ) . "\n";
                if( $paramStr ) {
                    #print "has param str\n";
                    $paramStr =~ s/\s//g;
                    $paramStr =~ s/^\(//;
                    $paramStr =~ s/\)$//;
                    my @paramParts = split(',',$paramStr);
                    push( @parts, { type => 'sub', name => $sub, params => \@paramParts, vars => [] } );
                }
                else {
                    push( @parts, { type => 'sub', name => $sub, params => [], vars => [] } );
                }
                next;
            }
            next if( $line =~ m/^\s*$/ ); # skip whitespace - could break heredocs
            next if( $line =~ m/^\s*#.+/ ); # skip whole line comments
            if( $line =~ m/^psub / ) {
                $line =~ s/^psub /sub /;
            }
            # TODO: deal with comments at end of lines... difficult...
            push( @parts, { type => 'line', text => "$line\n" } );
        }
        elsif( $mode eq 'rawtag' ) {
            if( $line =~ m|^\s*</([a-zA-Z_]+)>\s*$| ) {
                my $tagend = $1;
                if( $tagend eq $tagname ) {
                    #print "End of raw tag: $tagname\n";
                    $mode = 'normal';
                    $commentxml .= "]]></raw></$tagname>";
                    #print Dumper( $commentxml );
                    push( @parts, { type => 'xml', xmlText => $commentxml } );
                    next;
                }
            }
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
                    push( @parts, { type => 'xml', xmlText => $commentxml } );
                }
            }
            next;
        }
    }
    return \@parts;
}

# TODO: Generate System.pm with getmod function

# aka run_tag
sub process_tag {
    my ( $self, $modXML, $xml, $modinfo ) = @_;

    my $tags = $self->{'curTags'};
    my $taghash = $self->{'taghash'};
    
    #my $key = $xml->{'_key'};
    my $key = get_first_key( $xml );
    
    my $tagdata = $taghash->{ $key } ||= {};
    
    my $metacode = $xml->{ $key };
    if( !ref( $metacode ) && $metacode =~ m/^\s*$/ ) { $metacode = {}; }
    
    my $params = {
        modXML => $modXML, # xml from build config file for the module
        metacode => $metacode, # the xml node of the tag being run
        tagdata => $tagdata,
        modInfo => $modinfo, # hash containing some basic info about the module
        builder => $self
    };
        
    if( $tags->{ $key } ) {
        my $info = $tags->{ $key };
        my $func = $info->{'func'};
        return $func->( $info->{'mod'}, %$params );
    }

    return 0;
}

sub tag_page {
    my $self = shift;
    my %parm = @_;
    my $tag = $parm{'metacode'};
    my $builder = $parm{'builder'};
    my $systemName = $builder->{'system_name'} or confess "System name is not set";
    my $pageName = $tag->{'name'};
    my $subName = $builder->{'curSub'}{'name'};
    
    my $tagdata = $parm{'tagdata'};
    my $curmodName = $self->{'curmod'}{'name'};
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
    
    return [
        { action => 'add_var', self => 'mod_response', var => 'resp' },
        { action => 'add_mod', mod => 'router' },
        { action => 'add_mod', mod => 'response', delayed => 1 },
        { action => 'add_sub_var', sub => 'init', self => 'mod_router' },
        { action => 'add_sub_text', sub => 'init', text => "
            \$mod_router->register( '$systemName', '$pageName', \\&$subName, \$self );
        " }
    ];
}

sub tag_tag {
    my $self = shift;
    my %parm = @_;
    my $tag = $parm{'metacode'};
    my $builder = $parm{'builder'};
    my $modInfo = $parm{'modInfo'};
    my $tagName = $tag->{'name'};
    
    my $curSub = $builder->{'curSub'};
    $modInfo->{'hasTags'} = 1;
    my $subName = $curSub->{'name'};
    my $stage = $tag->{'stage'} || 'normal';
    my $type = $tag->{'type'} || 'normal';
    my $alias = $tag->{'alias'} || '';
    my $aliasStr = $alias ? ", alias => '$alias'" : '';
    #print "Registering tag $tagName\n";
    
    return [
        { action => 'add_sub', name => 'setup_tags', text => "
            sub setup_tags( builder ) {
            }
        " },
        { action => 'add_sub_text', sub => 'setup_tags', text => "
            \$builder->register_tag( name => '$tagName', func => \\&$subName, mod => \$self, stage => '$stage', type => '$type' $aliasStr );
        " } ,
    ];
}

sub tag_param {
    my $self = shift;
    my %parm = @_;
    my $tag = $parm{'metacode'};
    my $name = $tag->{'name'};
    my $var = $tag->{'var'} || $name;
    
    return "    my \$$var = \$_params{'$name'};\n";
}

sub run_sub {
    my $self = shift;
    my %parm = @_;
    my $module = $parm{'modXML'};
    my $sub = $parm{'metacode'};
    my $subName = $sub->{'name'};
    my $modinfo = $parm{'modInfo'};
        
    my $params = $sub->{'params'};
    
    my $out = "";
    $out .= "    my \$self=shift;\n" if( $subName ne 'new_inst' );
    
    for my $param ( @$params ) {
        $out .= "    my \$$param = shift;\n";
    }
    
    $out .= "  my \%_params = \@_;\n" if( $subName ne 'new_inst' );
    
    my $vars = $sub->{'vars'};
    
    #print "vars: ".Dumper( $vars );
    my %doneVars;
    
    for my $var ( @$vars ) {
        my $fromself = $var->{'self'};
        next if( $doneVars{ $fromself } );
        $doneVars{ $fromself } = 1;
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
    
    return $out;
}

sub tag_var {
    my $self = shift;
    my %parm = @_;
    
    my $sub = $self->{'curSub'};
    my $vars = $sub->{'vars'};
    push( @$vars, $parm{'metacode'} );
    return '';
}

sub tag_sysblock {
    my $self = shift;
    my %parm = @_;
    my $module = $parm{'modXML'};
    my $node = $parm{'metacode'};
    my $modinfo = $parm{'modInfo'};
    
    my $pkg = $self->{'pkg'};
    # modhash
    my $modhash = $self->{'modhash'};
    my $mods = deepclone( $modhash );
    my $out = '';
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
    $out .= $self->{'systemCreate'} || '';
    
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
                $out .= "    \$mods->{'$modname'} = $pkg$modname->new( conf => \$conf_$modname,\n";
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
    
    my $mods_with_tags = $self->{'mods_with_tags'};
    if( $mods_with_tags ) {
        $out .= "    my \$builder = \$_params{'builder'};
    if( \$builder ) {\n";    
        for my $mod_with_tag ( @$mods_with_tags ) {
            $out .= "\$mods->{'$mod_with_tag'}->setup_tags( \$builder ) if( \$mods->{'$mod_with_tag'} );\n";
        }
        $out .= "    }\n";
    }
    
    return $out;
}

sub output_conf {
    my ( $self, $modName ) = @_;
    my $modhash = $self->{'modhash'};
    my $modinfo = $modhash->{ $modName };
    
    my $buildXML = $modinfo->{'buildXML'};
    my $constructConf = $modinfo->{'construct_conf'};
    #print "$modName construct:".Dumper( $constructConf );
    #print "$modName buildXML:".Dumper( $buildXML );
    my $modXML = filter_xml( $constructConf, $buildXML );
    #print "$modName filtered:".Dumper( $modXML );
    
    my $xmlText = $modXML ? XML::Bare::Object::xml( 0, { xml => $modXML } ) : '<xml/>';
    return "
    my \$conf_$modName;
    if( \$_params{'conf_$modName'} ) {
        \$conf_$modName = \$_params{'conf_$modName'};
    }
    else {
        my \$conf_xml_$modName =<<'ENDEND';
$xmlText
ENDEND
        my ( \$ob_$modName, \$confX_$modName ) = XML::Bare->simple( text => \$conf_xml_$modName );
        \$conf_$modName = \$confX_${modName}->{'xml'};
    }\n";
}

sub filter_xml {
    my ( $filter, $data ) = @_;
    my $output = {};
    return $data if( !ref( $data ) );
    return {} if( !ref( $filter ) );
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

sub deepclone {
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

sub tag_new_inst {
    my $self = shift;
    my %parm = @_;
    
    my $node = $parm{'metacode'};
    my $modinfo = $parm{'modInfo'};
    my $modname = $modinfo->{'name'};
    my $pkg = $self->{'pkg'};
    
    return "
    my \$root = shift;
    my \$class = ref( \$root );
    my \%params = \@_;
    my \$self = bless { \%\$root }, \$class;
    
    \$self->init_inst(\%params) if( defined( &$pkg${modname}::init_inst ) && !\$self->{'skipInit'} );
    return \$self;\n";
}

sub tag_construct {
    my $self = shift;
    my %parm = @_;
    my $module = $parm{'modXML'};
    
    my $node = $parm{'metacode'};
    my $modinfo = $parm{'modInfo'};
    
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
        
    my $pkg = $self->{'pkg'};
    my $importedModules = $self->{'importedModules'};
    
    my $builder = $parm{'builder'};
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
    
    for my $depname ( keys %$deps ) {
        for my $var ( keys %{$deps->{$depname}} ) {
            #print "  Dep on mod $depname as var $var\n";
            $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";
        }
    }
    
    for my $depname ( keys %$imported_deps ) {
        for my $var ( keys %{$imported_deps->{$depname}} ) {
            #print "  Dep on mod $depname as var $var\n";
            $copy .= "    \$self->{'$var'} = \$params{'mod_$depname'} || 0;\n";
        }
    }

    
    return "sub new {
    my \$class = shift;
    my \%params = \@_;
    my \$self = bless {}, \$class;
    
    $copy    \$self->init(\%params) if( defined( &$pkg${modname}::init ) && !\$self->{'skipInit'} );
    return \$self;
}\n";
}

sub tag_header {
    my $self = shift;
    my %parm = @_;
    my $module = $parm{'modXML'};
    my $node = $parm{'metacode'};
    my $modinfo = $parm{'modInfo'};
    
    my $modname = $module->{'name'};
    my $pkg = $self->{'pkg'};
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

1;