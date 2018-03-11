package Melon::Builder::builder;
use XML::Bare qw/forcearray/;
use File::Slurp ;
use Data::Dumper ;
use Carp ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::builder::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@4
    my $self=shift;
  my %_params = @_;
    $self->{'action_handlers'} = {};#@5
    $self->{'sys'} = $SYS;#@6
    $self->{'lang'} = 'perl';#@7
    $self->{'trace'} = 0;#@8
}
sub setlang { #@11
    my $self=shift;
    my $lang = shift;
  my %_params = @_;
    $self->{'lang'} = $lang;#@12
}
sub init2 { #@15
    my $self=shift;
  my %_params = @_;
    my $mod_taghandlers = $self->{'mod_taghandlers'};
    my $mod_subwriter = $self->{'mod_subwriter'};
    my $mod_systemgen = $self->{'mod_systemgen'};
    my $mod_versiontracker = $self->{'mod_versiontracker'};
    my $file = $_params{'file'};#@16
    my $lang = $_params{'lang'};#@17
    if( $lang ) {
        $self->{'lang'} = $lang;#@20
    }
    else {
        $lang = $self->{'lang'};#@23
    }
    $mod_taghandlers->setlang( $lang );#@26
    $mod_subwriter->setlang( $lang );#@27
    $mod_systemgen->setlang( $lang );#@28
    $SYS->{g}{version_current} = $mod_versiontracker->new_inst();#@29
    $SYS->{g}{version_current}->trackInputFile( $file, { type => "system_conf" } );#@31
    my ( $ob, $xml ) = XML::Bare->simple( file => $file );#@32
    $xml = $self->{'xml'} = $xml->{'xml'};#@33
    if( $lang eq 'js' ) {
        $self->{'jsdep'} = $xml->{'jsdep'};#@35
        $self->{'css'} = $xml->{'css'};#@36
    }
    my $ns = $_params{'namespace'} || $xml->{'namespace'} || 'Melon/Default';#@42
    $self->{'namespace'} = $ns;#@43
    my $name = $_params{'name'};#@45
    if( !$name && $xml->{'name'} ) {
        $name = $xml->{'name'};#@47
    }
    $self->{'system_name'} = $self->{'name'} = $name;#@49
    my $dir = $self->{'dir'} = $_params{'dir'} || 'built';#@51
    $SYS->{g}{version_prev} = $mod_versiontracker->new_inst( file => $mod_systemgen->get_info_filename() );#@52
    $SYS->{g}{version_current}->trackVars( { sys_name => $name, sys_ns => $ns } );#@54
    if( ! -e "$dir/$ns" ) {
        my @parts = split( '/', $ns );#@57
        my $curpath = $dir;#@58
        for my $part ( @parts ) {
            $curpath .= "/$part";#@60
            if( ! -e $curpath ) {
                mkdir $curpath;#@62
            }
        }
    }
    my $pkg = $ns;#@68
    $pkg =~ s|/|::|g;#@69
    $pkg .= "::";#@70
    $self->{'pkg'} = $pkg;#@71
    my $pkgvar = $pkg;#@72
    $pkgvar =~ s/::/_/g;#@73
    $self->{'pkgvar'} = $pkgvar;#@74
}
sub parse_xml_parts { #@77
    my $self=shift;
    my $parts = shift;
  my %_params = @_;
    my $hasXmlPart = 0;#@78
    for my $part ( @$parts ) {
        next if( $part->{'type'} ne 'xml' );#@80
        $hasXmlPart = 1;#@81
        my $xmlText = $part->{'xmlText'};#@82
        if( !$xmlText ) {
            print Dumper( $part );#@84
            die;#@85
        }
        my ( $o1, $x1 ) = XML::Bare->simple( text => $part->{'xmlText'} );#@87
        $part->{'xml'} = $x1;#@88
    }
    return $hasXmlPart;#@90
}
sub get_first_key {
    my $hash = shift;#@94
    for my $key ( keys %$hash ) {
        next if( $key =~ m/^_/ );#@96
        return $key;#@97
    }
    return '';#@99
}
sub setup_tag_stages { #@102
    my $self=shift;
  my %_params = @_;
    my $mod_taghandlers = $self->{'mod_taghandlers'};
    my $raw_tags = $self->{'raw_tags'} = {};#@103
    my $stages = $mod_taghandlers->setup_stages();#@104
    my $stage_hash = $self->{'stage_hash'} = {};#@106
    for my $stage ( @$stages ) {
        my $name = $stage->{'name'};#@108
        $stage_hash->{ $name } = $stage;#@109
    }
    return $stages;#@112
}
sub build_module { #@115
    my $self=shift;
    my $module = shift;
  my %_params = @_;
    my $mod_subwriter = $self->{'mod_subwriter'};
    my $trace = $_params{'trace'};#@116
    my $lang = $self->{'lang'};#@118
    my $module_build_res = $self->{'module_build_result'} = {};#@119
    my $taghash = $self->{'taghash'} = {};#@120
    my $modhash = $self->{'modhash'};#@121
    $self->{'curmod'} = $module;#@122
    my $modname = $module->{'name'};#@123
    print "\n===== Processing module $modname =====\n";#@124
    my %modinfo = ( name => $modname, buildXML => $module );#@125
    $modhash->{ $modname } = \%modinfo;#@126
    $module->{'_cpan'} = forcearray( $module->{'cpan'} );#@127
    my $file = $module->{'file'};#@129
    my $data;#@130
    my $rt;#@131
    if( ( $rt = ref( $file ) ) && $rt eq 'ARRAY' ) {
        for my $aFile ( @$file ) {
            $data .= read_file( $aFile );#@134
        }
    }
    else {
        $data = read_file( $file );#@138
    }
    my @rawlines = split(/\n/, $data);#@141
    my @lines;#@142
    my $numlines = scalar @rawlines;#@143
    for( my $ln=1;$ln<=$numlines;$ln++) {
        my $rawline = $rawlines[$ln-1];#@145
        push( @lines, { text => $rawline, ln => $ln } );#@146
    }
    my $parts = $self->split_lines_to_parts( \@lines );#@149
    $self->parse_xml_parts( $parts );#@150
    $self->{'subhash'} = {};#@152
    my $subs = $self->{'subs'} = $self->split_parts_to_subs( $parts );#@153
    my $subhash = $self->{'subhash'};#@154
    my $stages = $self->{'tag_stages'};#@158
    for my $stage ( @$stages ) {
        $self->{'curTags'} = $stage->{'tags'};#@160
        $self->{'stage'} = $stage;#@161
        my $stageName = $stage->{'name'};#@163
        if( $stageName eq 'preconstruct' ) {
            for my $cursub ( @$subs ) {
                my $subName  = $cursub->{'name'};#@169
                my $subParts = $cursub->{'parts'};#@170
                for my $Apart ( @$subParts ) {
                    next if( $Apart->{'type'} ne 'line' );#@173
                    my $part = $Apart->{'text'};#@174
                    my %usedMods;#@175
                    while( $part =~ m/\$mod_([a-zA-Z0-9_]+)/g ) {
                        $usedMods{$1} = ( $subName eq 'init' ) ? 'normal' : 'delayed';#@177
                    }
                    if( $trace ) {
                        if( $lang eq 'perl' ) {
                            $part =~ s/\$mod_([a-zA-Z0-9_]+)->([a-zA-Z0-9_]+)\(([^\(\)]+\))/\$mod_${1}->${2}($3,'_trId' => \$_trId)/g;#@185
                            $part =~ s/\$self->([a-zA-Z0-9_]+)\(([^\(\)]+\))/\${self}->${1}($2,'_trId' => \$_trId)/g;#@187
                        }
                    }
                    $part =~ s/\$global_([a-zA-Z0-9_]+)/\$SYS->{g}{$1}/g;#@190
                    $Apart->{'text'} = $part;#@191
                    for my $modName ( keys %usedMods ) {
                        my $depType = $usedMods{ $modName };#@193
                        my $construct = $taghash->{'construct'} ||= {};#@195
                        my $modules = $construct->{'modules'} ||= {};#@196
                        if( !$modules->{ $modName } ) {
                            $modules->{ $modName } = { delayed => ( $depType eq 'delayed' ), var => "mod_$modName" }
                        }
                        elsif( $depType ne 'delayed' ) { # Overwrite currently delayed modules with non-delayed hard dependency
                            $modules->{ $modName } = { delayed => 0, var => "mod_$modName" }
                        }
                        my $vars = $cursub->{'vars'};#@205
                        push( @$vars, { self => "mod_$modName", var => "mod_$modName" } );#@206
                    }
                }
            }
            next;#@210
        }
        for my $cursub ( @$subs ) {
            $self->{'cursub'} = $cursub;#@214
            $cursub->{'parts'} = $self->process_xml_parts( $module, \%modinfo, $cursub->{'parts'} );#@215
        }
    }
    my ( $output, $outputTraced ) = $mod_subwriter->write( $subs, $module, \%modinfo );#@220
    my $ns = $self->{'namespace'};#@222
    if( $lang eq 'perl' ) {
        $output .= "\n1;\n";#@225
    }
    my $dir = $self->{'dir'};#@228
    my $modulePath;#@229
    my $modulePathTraced;#@230
    if( $lang eq 'perl' ) {
        $modulePath = "$dir/$ns/$modname.pm";#@233
        $modulePathTraced = "$dir/$ns/$modname.tpm";#@234
    }
    if( $lang eq 'js' ) {
        $modulePath = "$dir/$ns/$modname.js";#@237
        $modulePathTraced = "$dir/$ns/$modname.tjs";#@238
    }
    write_file( $modulePath, $output );#@240
    write_file( $modulePathTraced, $outputTraced );#@241
    $SYS->{g}{version_current}->trackOutputFile( $file, { type => "mod", mod => $modname } );#@242
    if( $lang eq 'perl' ) {
        $self->check_compile( $modname, $modulePath, $output );#@244
    }
    return $module_build_res;#@247
}
sub check_compile { #@250
    my $self=shift;
    my $modName = shift;
    my $modFile = shift;
    my $gen = shift;
  my %_params = @_;
    my $code = "perl -c $modFile 2>\&1";#@256
    my $err = `$code`;#@258
    my $errCode = $?;#@259
    return if( $errCode==0 );#@260
    my @genLines = split("\n",$gen);#@262
    my @errLines = split("\n",$err);#@265
    for my $line ( @errLines ) {
        if( $line =~ m/(.+) at [^ ]+ line (.+)(\.|,)/ ) {
            my $err = $1;#@268
            my $ln = $2;#@269
            print "Error in $modName\n  $err\n";#@270
            my $approx_line = $self->get_approx_line( \@genLines, $ln );#@271
            if( $approx_line eq '?' ) {
                print "  Built Line: $ln ( see $modFile )\n";#@273
            }
            else {
                print "  Source Line: $approx_line\n";#@276
            }
        }
    }
}
sub get_approx_line { #@282
    my $self=shift;
    my $lines = shift;
    my $ln = shift;
  my %_params = @_;
    my $totLines = scalar @$lines;#@283
    my $offset = 0;#@284
    for( my $lineNum=$ln-1;$lineNum<$totLines;$lineNum++ ) {
        my $line = $lines->[ $lineNum ];#@286
        if( $line =~ m/#\@([0-9]+)/ ) {
            my $srcLN = $1;#@288
            if( $offset ) { return "< $srcLN (approx)"; }
            return $srcLN;#@290
        }
        $offset++;#@292
    }
    return '?';#@294
}
sub build { #@297
    my $self=shift;
  my %_params = @_;
    my $mod_systemgen = $self->{'mod_systemgen'};
    my $skipModules = $_params{'skipModules'};#@298
    my $forceRebuild = $_params{'forceRebuild'};#@299
    my $trace = $_params{'trace'};#@300
    if( $trace ) {
        $self->{'trace'} = 1;#@303
    }
    my $xml = $self->{'xml'};#@306
    $self->setup_tag_stages();#@308
    if( $xml->{'system'} ) {
        my $systems = forcearray( $xml->{'system'} );#@311
        $mod_systemgen->load_systems( $systems );#@312
    }
    $self->{'modhash'} = {};#@315
    my %skipHash;#@317
    if( $skipModules ) {
        for my $skipMod ( @$skipModules ) {
            print "Will skip module '$skipMod'\n";#@320
            $skipHash{ $skipMod } = 1;#@321
        }
    }
    my $modules = forcearray( $xml->{'module'} );#@325
    for my $module ( @$modules ) {
        my $modName = $module->{'name'};#@328
        my $file = $module->{'file'};#@329
        my $rt;#@330
        if( ( $rt = ref($file) ) && $rt eq 'ARRAY' ) {
            for my $aFile ( @$file ) {
                $SYS->{g}{version_current}->trackInputFile( $aFile, { type => 'mod', mod => $modName } );#@333
            }
        }
        else {
            $SYS->{g}{version_current}->trackInputFile( $file, { type => 'mod', mod => $modName } );#@337
        }
    }
    if( !$forceRebuild && $SYS->{g}{version_current}->equals( $SYS->{g}{version_prev} ) ) {
        print "Input files have not changed; continuing without rebuilt\n";#@342
        return;#@343
    }
    my $sysModule = 0;#@346
    while( @$modules ) {
        my $module = shift @$modules;#@348
        my $modName = $module->{'name'};#@349
        if( $modName eq 'systemx' ) {
            $sysModule = $module;#@351
            next;#@352
        }
        next if( $skipHash{ $modName } );#@354
        my $res = $self->build_module( $module, trace => $trace );#@355
        if( $res->{'new_modules'} ) {
            print "Adding module(s):\n";#@357
            for my $addMod ( @{$res->{'new_modules'}} ) {
                my $modDup = { %$addMod };#@359
                $modDup->{'file'} = { value => $modDup->{'file'}, _att => 1 } if( $modDup->{'file'} );#@360
                $modDup->{'name'} = { value => $modDup->{'name'}, _att => 1 } if( $modDup->{'name'} );#@361
                $modDup->{'multiple'} = { value => $modDup->{'multiple'}, _att => 1 } if( $modDup->{'multiple'} );#@362
                my $xml = XML::Bare::Object::xml( 0, { mod => $modDup } );#@363
                print "  $xml";#@364
            }
            unshift( @$modules, @{$res->{'new_modules'}} );#@366
        }
    }
    $self->build_module( $sysModule );#@370
    $mod_systemgen->write_info_file( $self->{'modhash'} );#@372
}
sub register_action { #@375
    my $self=shift;
    my $action = shift;
    my $func = shift;
    my $mod = shift;
  my %_params = @_;
    $self->{'action_handlers'}{$action} = { func => $func, mod => $mod };#@376
}
sub process_xml_parts { #@379
    my $self=shift;
    my $module = shift;
    my $modinfo = shift;
    my $subParts = shift;
  my %_params = @_;
    my $mod_tagsystem = $self->{'mod_tagsystem'};
    my $tags = $self->{'curTags'};#@380
    my $cursub = $self->{'cursub'};#@381
    my $subName  = $cursub->{'name'};#@382
    my $taghash = $self->{'taghash'};#@383
    my $subhash = $self->{'subhash'};#@384
    my $module_build_result = $self->{'module_build_result'};#@385
    my $actionHandlers = $self->{'action_handlers'};#@386
    my $partsOut = [];#@389
    for my $part ( @$subParts ) {
        next if( !$part );#@391
        if( $part->{'type'} ne 'xml' ) {
            push( @$partsOut, $part );#@393
            next;#@394
        }
        my $ln = $part->{'ln'} || '?';#@396
        my $key = get_first_key( $part->{'xml'} );#@398
        if( !$key ) {
            print "No valid first key: ".Dumper($part);#@400
        }
        if( $tags->{$key} ) { # only process tags that are in this stage
            my $actions = $mod_tagsystem->process_tag( $module, $part->{'xml'}, $modinfo, $ln );#@405
            if( my $reftype = ref( $actions ) ) {
                if( $reftype ne 'ARRAY' ) {
                    confess( "Result of running tag $key - > " . Dumper( $actions ) ); 
                }
                for my $actionNode ( @$actions ) {
                    my $action = $actionNode->{'action'};#@413
                    if( !$action ) {
                        print "Action has no type: ".Dumper( $actionNode );#@415
                    }
                    my $handler = $actionHandlers->{$action};#@418
                    my $func = $handler->{'func'};#@419
                    my $extraParts = $func->( $handler->{'mod'}, $actionNode, $taghash, $cursub, $subhash, module => $module, modinfo => $modinfo, ln => $ln );#@420
                    if( $extraParts ) {
                        for my $extraPart ( @$extraParts ) {
                            next if( !%$extraPart );#@423
                            $extraPart->{'ln'} = $ln;#@424
                        }
                        push( @$partsOut, @$extraParts );#@426
                    }
                }
            }
            else {
                my $resultText = $actions;#@440
                $part->{'text'} = $resultText;#@441
                $part->{'type'} = 'line';#@442
                push( @$partsOut, $part );#@443
            }
        }
        else {
            push( @$partsOut, $part );#@448
        }
    }
    return $partsOut;#@453
}
sub split_parts_to_subs { #@456
    my $self=shift;
    my $parts = shift;
  my %_params = @_;
    my $subhash = $self->{'subhash'} ||= {};#@457
    my @subs;#@458
    my $cursub = { type => 'init' };#@460
    my $curparts = [];#@461
    $cursub->{'parts'} = $curparts;#@462
    for my $part ( @$parts ) {
        my $type = $part->{'type'};#@465
        if( $type eq 'sub' ) {
            push( @subs, $cursub );#@467
            my $newSubName = $part->{'name'};#@468
            my $subLn = $part->{'ln'} || '?';#@469
            $curparts = [ $part ];#@470
            $cursub = {
                type => 'sub',
                name => $newSubName,
                parts => $curparts,
                vars => $part->{'vars'},
                params => $part->{'params'},
                ln => $subLn
            };#@478
            $subhash->{ $newSubName } = $cursub;#@479
            next;#@480
        }
        push( @$curparts, $part );#@482
    }
    push( @subs, $cursub );#@484
    return \@subs;#@486
}
sub split_lines_to_parts { #@489
    my $self=shift;
    my $lines = shift;
  my %_params = @_;
    my $incomment = 0;#@490
    my $commentxml = '';#@491
    my @parts;#@492
    my $tagname = '';#@493
    my $mode = "normal";#@495
    my $rawBegin;#@496
    my $rawEnd;#@497
    my $raw_tags = $self->{'raw_tags'};#@499
    while( @$lines ) {
        my $lineOb = shift @$lines;#@502
        my $line;#@503
        my $ln;#@504
        if( !ref( $lineOb ) ) {
            $line = $lineOb;#@506
            $ln = '?';#@507
        }
        else {
            $line = $lineOb->{'text'};#@510
            $ln = $lineOb->{'ln'};#@511
        }
        if( $mode eq 'normal' ) {
            if( $line =~ m/^`(.+)/ ) { # raw line
                push( @parts, { type => 'line', text => "$1\n", ln => $ln } );#@515
                next;#@516
            }
            if( $line =~ m|^\s*<!--.+-->\s*$| ) { # xml style comment
                next;#@519
            }
            if( $line =~ m|^\s*(<.+/>)$| ) { # self closing xml
                push( @parts, { type => 'xml', xmlText => "$1", ln => $ln } );#@522
                next;#@523
            }
            if( $line =~ m|^\s*<([a-zA-Z_]+)| ) { # start of XML block
                $tagname = $1;#@526
                if( $line =~ m|</$tagname>\s*$| ) { # closing tag on the same line
                    push( @parts, { type => 'xml', xmlText => "$line", ln => $ln } );#@528
                    next;#@529
                }
                if( $raw_tags->{ $tagname } ) {
                    $commentxml = "$line<raw><![CDATA[";#@533
                    $mode = 'rawtag';#@534
                    $rawBegin = $ln + 1;#@535
                    next;#@536
                }
                if( $line =~ m/>\[\[$/ ) {
                    $line = substr( $line, 0, -2 );#@539
                    $line .= "<![CDATA[";#@540
                }
                $commentxml = "$line\n";#@543
                $mode = 'xml';#@544
                next;#@545
            }
            if( $line =~ m/^\s*sub ([a-zA-Z0-9_-]+)\s*(\(\s*[a-zA-Z0-9_-]+\s*(,\s*[a-zA-Z0-9_-]+)*\s*\))?\s*\{\s*$/ ) {
                my $sub = $1;#@549
                my $paramStr = $2;#@550
                if( $paramStr ) {
                    $paramStr =~ s/\s//g;#@554
                    $paramStr =~ s/^\(//;#@555
                    $paramStr =~ s/\)$//;#@556
                    my @paramParts = split(',',$paramStr);#@557
                    push( @parts, {
                        type => 'sub',
                        name => $sub,
                        params => \@paramParts,
                        vars => [],
                        ln => $ln
                    } );#@564
                }
                else {
                    push( @parts, {
                        type => 'sub',
                        name => $sub,
                        params => [],
                        vars => [],
                        ln => $ln
                    } );#@573
                }
                next;#@575
            }
            next if( $line =~ m/^\s*$/ ); # skip whitespace - could break heredocs
            next if( $line =~ m/^\s*#.+/ ); # skip whole line comments
            if( $line =~ m/^psub / ) {
                $line =~ s/^psub /sub /;#@580
            }
            push( @parts, { type => 'line', text => "$line\n", ln => $ln } );#@583
        }
        elsif( $mode eq 'rawtag' ) {
            if( $line =~ m|^\s*</([a-zA-Z_]+)>\s*$| ) {
                $rawEnd = $ln;#@587
                my $tagend = $1;#@588
                if( $tagend eq $tagname ) {
                    $mode = 'normal';#@591
                    $commentxml .= "]]></raw></$tagname>";#@592
                    push( @parts, { type => 'xml', xmlText => $commentxml, ln => $rawBegin } );#@594
                    next;#@595
                }
            }
            $line =~ s/]]>/||>/g; # prevent contents of raw tag from ending cdata
            $commentxml .= "$line\n";#@599
        }
        elsif( $mode eq 'xml' ) {
            if( $line =~ m/>\[\[$/ ) {
                $line = substr( $line, 0, -2 );#@603
                $line .= "<![CDATA[";#@604
            }
            if( $line =~ m|^\s*<!--.+-->\s*$| ) { # xml style comment
                next;#@607
            }
            $commentxml .= "$line\n";#@609
            if( $line =~ m|^\s*(\]\]>)?</([a-zA-Z_]+)>$| ) {
                my $tagend = $2;#@611
                if( $tagend eq $tagname ) {
                    $mode = 'normal';#@613
                    push( @parts, { type => 'xml', xmlText => $commentxml, ln => $ln } );#@614
                }
            }
            next;#@617
        }
    }
    return \@parts;#@620
}

1;
