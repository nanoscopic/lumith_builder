package Builder::Core::templates;
use File::Slurp ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::templates::init ) && !$self->{'skipInit'} );
                return $self;
            }use Digest::MD5 qw/md5_hex/;#@5
sub init { #@7
    my $self=shift;
  my %_params = @_;
    $self->{'tags'} = {
        var => { sub => \&tpl_var, obj => $self },
        varq => { sub => \&tpl_varq, obj => $self },
        dest => { sub => \&tpl_dest, obj => $self },
        code => { sub => \&tpl_code, obj => $self },
        dump => { sub => \&tpl_dump, obj => $self }
    };#@14
    my $tpl_pm_dir = $self->{'tpl_pm_dir'} = "/tmp/tpl_pm";#@15
    $self->{'tpl_hash'} = {};#@16
    $self->{'tpl_refs'} = {};#@17
    $self->{'lang'} = 'perl';#@18
    $self->load_cached_templates();#@19
    if( ! -e $tpl_pm_dir ) {
        mkdir $tpl_pm_dir;#@22
    }
}
sub tpl_dest { #@26
    my $self=shift;
    my $tag = shift;
    my $in = shift;
    my $out = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $mod_urls = $self->{'mod_urls'};
    my $pageName = $tag->{'page'};#@28
    if( $lang eq 'perl' ) {
        return "  $out .= \$mod_urls->genDest( page => '$pageName' );\n";#@30
    }
    elsif( $lang eq 'js' ) {
        return "  $out += \$mod_urls.genDest( { page: '$pageName' } );\n";#@33
    }
}
sub tpl_var { #@37
    my $self=shift;
    my $tag = shift;
    my $in = shift;
    my $out = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $varName = $tag->{'name'};#@39
    if( $lang eq 'perl' ) {
        if( $varName eq 'else' ) {
            return "\n} else {\n";#@42
        }
        if( $in eq '' || $tag->{'direct'} ) {
            return "  $out .= \$$varName;\n";#@45
        }
        else {
            return "  $out .= ${in}{'$varName'};\n";#@48
        }
    }
    elsif( $lang eq 'js' ) {
        if( $varName eq 'else' ) {
            return "\n} else {\n";#@53
        }
        if( $in eq '' || $tag->{'direct'} ) {
            return "  $out += $varName;\n";#@56
        }
        else {
            return "  $out += ${in}.$varName;\n";#@59
        }
    }
use Sub::Identify qw/sub_name/;#@63
use Scalar::Util qw/blessed/;#@64
}
sub dump { #@65
    my $self=shift;
    my $ob = shift;
  my %_params = @_;
    my $className = blessed( $ob );#@66
    return $className if( $className );#@67
    my $rtype = ref( $ob );#@68
    if( $rtype eq 'CODE' ) {
        return sub_name( $ob );#@70
    }
    return substr( Dumper( $ob ), 8 );#@72
}
sub tpl_dump { #@75
    my $self=shift;
    my $tag = shift;
    my $in = shift;
    my $out = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $mod_templates = $self->{'mod_templates'};
    my $varName = $tag->{'name'};#@77
    if( $lang eq 'perl' ) {
        if( $in eq '' || $tag->{'direct'} ) {
            return "  $out .= \$mod_templates->dump( \$$varName );\n";#@80
        }
        else {
            return "  $out .= \$mod_templates->dump( ${in}{'$varName'} );\n";#@83
        }
    }
    elsif( $lang eq 'js' ) {
        if( $in eq '' || $tag->{'direct'} ) {
            return "  out += \$mod_templates.dump( $varName );\n";#@88
        }
        else {
            return "  $out += \$mod_templates.dump( ${in}.$varName );\n";#@91
        }
    }
}
sub escape { #@96
    my $self=shift;
    my $str = shift;
  my %_params = @_;
    use Data::Dumper;#@97
    my $dump = Dumper( $str );#@98
    my $res = substr( $dump, 8, -2 );#@99
    $res =~ s/\n/'."\\n".'/g; # hackily inline carriage returns so that the code looks less messy
    $res =~ s/\.''$//; # strip trailing addition of empty string because it is pointless ( caused by previous line )
    return $res;#@102
}
sub escapeForJS { #@107
    my $self=shift;
    my $str = shift;
  my %_params = @_;
    use Data::Dumper;#@108
    my $dump = Dumper( $str );#@109
    my $res = substr( $dump, 8, -2 );#@110
    $res =~ s/\n/'+"\\n"+'/g; # hackily inline carriage returns so that the code looks less messy
    $res =~ s/\+''$//; # strip trailing addition of empty string because it is pointless ( caused by previous line )
    return $res;#@113
}
sub tpl_varq { #@118
    my $self=shift;
    my $tag = shift;
    my $in = shift;
    my $out = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $mod_templates = $self->{'mod_templates'};
    my $varName = $tag->{'name'};#@120
    my $valstr;#@121
    if( $lang eq 'perl' ) {
        if( $in eq '' ) {
            $valstr = "\$$varName";#@124
        }
        else {
            $valstr = "${in}{'$varName'}";#@127
        }
        return "  $out .= \$mod_templates->escape( $valstr );\n";#@129
    }
    if( $lang eq 'js' ) {
        if( $in eq '' ) {
            $valstr = "$varName";#@133
        }
        else {
            $valstr = "${in}.$varName";#@136
        }
        return "  $out += \$mod_templates.escape( $valstr );\n";#@138
    }
}
sub tpl_code { #@142
    my $self=shift;
    my $tag = shift;
    my $in = shift;
    my $out = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $data = $tag->{'data'};#@144
    if( $data =~ m/^\+/ ) {
        $data = substr( $data, 1 );#@146
        if( $lang eq 'perl' ) {
            return "  $out .= ($data);";#@148
        }
        if( $lang eq 'js' ) {
            return "  $out += ($data);";#@151
        }
    }
    return "$data\n";#@154
}
sub register_tpl_tag { #@157
    my $self=shift;
    my $tplName = shift;
    my $callback = shift;
    my $callbackObj = shift;
  my %_params = @_;
    $self->{'tags'}{ $tplName } = { sub => $callback, obj => $callbackObj };#@158
}
sub run_tpl_tag { #@161
    my $self=shift;
    my $key = shift;
    my $node = shift;
    my $invar = shift;
    my $outvar = shift;
  my %_params = @_;
    my $callback = $self->{'tags'}{ $key };#@162
    die "Invalid template tag $key" if( !$callback );#@163
    my $sub = $callback->{'sub'};#@164
    my $obj = $callback->{'obj'};#@165
    return $sub->( $obj, $node, $invar, $outvar );#@166
}
sub tag_template_tag { #@169
    my $self=shift;
  my %_params = @_;
    my $mod_templates = $self->{'mod_templates'};
    my $tag = $_params{'metacode'};#@172
    my $builder = $_params{'builder'};#@174
    my $pageName = $tag->{'name'};#@176
    my $subName = $builder->{'cursub'}{'name'};#@177
    return [
        { action => 'add_var', self => 'mod_templates', var => 'tmpl' },
        { action => 'add_sub_text', sub => 'init', text => "\
            \$mod_templates->register_tpl_tag( '$pageName', \\&$subName, \$self );\
        " }
    ];#@184
}
sub load_cached_templates { #@187
    my $self=shift;
  my %_params = @_;
    my $tpl_pm_dir = $self->{'tpl_pm_dir'};
    return if( ! -e $tpl_pm_dir );#@190
    opendir( my $dh, $tpl_pm_dir );#@191
    my @files = readdir( $dh );#@192
    closedir( $dh );#@193
    for my $file ( @files ) {
        next if( $file =~ m/^\.+$/ );#@196
        $self->load_cached_template( "$tpl_pm_dir/$file", $file );#@197
    }
}
sub load_cached_template { #@201
    my $self=shift;
    my $path = shift;
    my $file = shift;
  my %_params = @_;
    my $tpl_refs = $self->{'tpl_refs'};
    my $lang = $self->{'lang'};
    require $path;#@205
    if( $file =~ m/^tpl_(.+)_([A-Za-z0-9]+)$/ ) {
        my $id = $1;#@207
        my $shortRef = $2;#@208
        my $ref = "TPL_${id}_$shortRef"->new();#@210
        $tpl_refs->{ $shortRef } = 1;#@211
        my $info = $ref->info();#@213
        $info->{'ref'} = $ref;#@214
        $info->{'loaded'} = 1;#@215
        my $md5 = $info->{'md5'};#@216
        my $tpls = $self->{'tpl_hash'};#@218
        my $tpl_set = $tpls->{$id};#@219
        if( !$tpl_set ) {
            $tpl_set = $tpls->{$id} = { id => $id, lang => $lang };#@221
        }
        $tpl_set->{ $md5 } = $info;#@224
    }   
}
sub fetch_template { #@228
    my $self=shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@229
    my $source = $_params{'source'};#@230
    my $id = $_params{'id'};#@231
    my $tpls = $self->{'tpl_hash'};#@233
    my $tpl_set = $tpls->{$id};#@234
    if( !$tpl_set ) {
        $tpl_set = $tpls->{$id} = { id => $id, lang => $lang };#@236
    }
    my $md5 = md5_hex( $source );#@239
    my $tpl = $tpl_set->{$md5};#@241
    if( !$tpl ) {
        my $shortRef = $self->new_shortRef( $md5 );#@243
        my $file;#@244
        if( $lang eq 'perl' ) {
            $file = "tpl_${id}_$shortRef.pm";#@246
        }
        if( $lang eq 'js' ) {
            $file = "tpl_${id}_$shortRef.js";#@249
        }
        $tpl = $tpl_set->{$md5} = {
            file => $file,
            loaded => 0,
            ref => 0,
            generated => time(),
            shortRef => $shortRef,
            id => $id,
            md5 => $md5
        };#@259
    }
    else {
        return $tpl;#@262
    }
    if( $tpl->{'ref'} ) { # template is already loaded in memory ( for perl at least )
        return $tpl;#@266
    }
    my $filename = $tpl->{'file'};#@272
    my $file = $self->{'tpl_pm_dir'} . '/' . $filename;#@273
    my $shortRef = $tpl->{'shortRef'};#@274
        my $code;#@277
        if( $lang eq 'perl' ) {
            $code = $self->template_to_code( $source, 0, 0, '$out', '$invar->' );#@279
        }
        if( $lang eq 'js' ) {
            $code = $self->template_to_code( $source, 0, 0, 'out', 'invar' );#@282
        }
        my $flatinfo = { %$tpl };#@285
        delete $flatinfo->{'ref'};#@286
        delete $flatinfo->{'loaded'};#@287
        my $flatText;#@288
        if( $lang eq 'perl' ) {
            $flatText = XML::Bare::Object::xml( 0, $flatinfo );#@290
        }
        if( $lang eq 'js' ) {
        }
        my $out;#@296
        if( $lang eq 'perl' ) {
            $out = "\
            package TPL_${id}_$shortRef;\
            use XML::Bare;\
            sub new {\
                my \$class = shift;\
                my \%params = \@_;\
                my \$self = bless {}, \$class;\
                return \$self;\
            }\
            sub info {\
                my ( \$ob, \$xml ) = XML::Bare::simple( text => " . $self->escape( $flatText ) . " );\
                return \$xml;\
            }\
            sub run {\
                my ( \$self, \$invar ) = \@_;\
                $code\
                return \$out;\
            }\
            1;\
            ";#@317
        }
        if( $lang eq 'js' ) {
            $out = $code;#@321
        }
        write_file( $file, $out );#@323
    if( $lang eq 'perl' ) {
        require $file;#@327
        $tpl->{'ref'} = "TPL_${id}_$shortRef"->new();#@328
    }
    if( $lang eq 'js' ) {
        $tpl->{'ref'} = 1;#@332
    }
    return $tpl;#@335
}
sub new_shortRef { #@338
    my $self=shift;
    my $md5 = shift;
  my %_params = @_;
    my $tpl_refs = $self->{'tpl_refs'};
    my $len = length( $md5 );#@340
    for( my $i=1;$i<=$len;$i++ ) {
        my $part = substr( $md5, 0, $i );#@342
        if( !$tpl_refs->{ $part } ) {
            $tpl_refs->{ $part } = 1;#@344
            return $part;#@345
        }
    }
    return $md5;#@348
}
sub tag_template { #@351
    my $self=shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    my $modXML = $_params{'modXML'};#@354
    my $tag = $_params{'metacode'};#@355
    my $modInfo = $_params{'modInfo'};#@356
    my $ln = $_params{'ln'};#@357
    my $invar;#@359
    my $outvar = '';#@360
    my $append = 0;#@361
    if( exists $tag->{'append'} ) {
        $append = 1;#@363
        if( my $out = $tag->{'out'} ) {
            if( $lang eq 'perl' ) {
                $outvar = "\$$out";#@366
            }
            if( $lang eq 'js' ) {
                $outvar = "\$$out";#@369
            }
        }
        else {
            $outvar = $self->{'prev_outvar'} || 'return';#@373
        }
        if( my $in = $tag->{'in'} ) {
            $invar = '' if( $in eq 'direct' );#@377
        }
    }
    else {
        my $in = $tag->{'in'} || '%_params';#@381
        if( $in =~ m/^\%(.+)/ ) {
            my $name = $1;#@384
            if( $lang eq 'perl' ) {
                $invar = "\$$name";#@386
            }
            if( $lang eq 'js' ) {
                $invar = $name;#@389
            }
        }
        elsif( $in =~ m/^\$(.+)/ ) {
            my $name = $1;#@393
            if( $lang eq 'perl' ) {
                $invar = "\$${name}->";#@395
            }
            if( $lang eq 'js' ) {
                $invar = $name;#@398
            }
        }
        elsif( $in eq 'direct' ) {
            $invar = '';#@402
        }
        else {
            if( $lang eq 'perl' ) {
                $invar = '$'.$in."->";#@406
            }
            if( $lang eq 'js' ) {
                $invar = $in;#@409
            }
        }
        my $out = $tag->{'out'} || 'return';#@414
        if( $lang eq 'perl' ) {
            if( $out eq 'return' ) {
                $outvar = '$out';#@418
            }
            else {
                $outvar = "\$$out";#@421
            }
        }
        if( $lang eq 'js' ) {
            if( $out eq 'return' ) {
                $outvar = '$out';#@426
            }
            else {
                $outvar = "$out";#@429
            }
        }
    }
    if( ( ! defined $invar ) && defined $self->{'prev_invar'} ) {
        $invar = $self->{'prev_invar'};#@435
    }
    if( ! defined $invar ) {
        print "Invar is not defined:\n";#@439
        use Data::Dumper;#@440
        die Dumper( $tag );#@441
    }
    $self->{'prev_outvar'} = $outvar;#@444
    $self->{'prev_invar'} = $invar;#@445
    my $rawdata = $tag->{'raw'};#@446
    $rawdata =~ s/||>/]]>/g; # undo hack added to builder to allow cdatas within raw tag blocks
    return $self->template_to_code( $tag->{'raw'}, $append, $ln, $outvar, $invar );#@448
}
sub template_to_code { #@451
    my $self=shift;
    my $text = shift;
    my $append = shift;
    my $ln = shift;
    my $outvar = shift;
    my $invar = shift;
  my %_params = @_;
    my $lang = $self->{'lang'};
    $text =~ s/\*<(.+?)>\*/\%\%\%*<$1>\%\%\%/g; # Split out *<>* tags
    $text =~ s/\*\{([a-zA-Z0-9_]+)\}/\%\%\%*<var name='$1'\/>\%\%\%/g; # *{[word]} vars ( named template variable )
    $text =~ s/\*\{\$([a-zA-Z0-9_]+)\}/\%\%\%*<var name='$1' direct=1\/>\%\%\%/g; # *{$[word]} vars ( "direct" local variable usage )
    $text =~ s/\*\{\!([a-zA-Z0-9_]+)\}/\%\%\%*<dump name='$1'\/>\%\%\%/g; # *{![word]}
    $text =~ s/\*\{['"]{1,2}([a-zA-Z0-9_]+)\}/\%\%\%*<varq name='$1'\/>\%\%\%/g; # *{''[word]} vars ( they are put in a string )
    $text =~ s|\*\{if (.+?)\}|\%\%\%*<code><data><![CDATA[if($1){\n]]></data></code>\%\%\%|gs; # *{if [perl if expr]}
    $text =~ s|\*\{/if\}|\%\%\%*<code><data>}\n</data></code>\%\%\%|gs; # *{/if}
    $text =~ s|\*\{(.+?)\}\*|\%\%\%*<code><data><![CDATA[$1]]></data></code>\%\%\%|gs; # *{[perl code]}*
    $text =~ s/(\%\%\%)+/\%\%\%/g; # ensure magic sequence doesn't repeat multiple times in a row
    my @lines = split(/\n/,$text);#@463
    my @lines2 = '';#@464
    my $i = 0;#@465
    for my $line ( @lines ) {
        my $lnOff = $ln + $i;#@467
        push( @lines2, "$line---$lnOff" );#@469
        $i++;#@470
    }
    $text = join("\n",@lines2);#@472
    my $out;#@479
    if( $append ) {
        $out = '';#@481
    }
    else {
        if( $lang eq 'perl' ) {
            $out = "my $outvar = '';\n";#@485
        }
        if( $lang eq 'js' ) {
            $out = "var $outvar = '';\n";#@488
        }
    }
    my $curLn = $ln;#@491
    my @parts = split( '%%%', $text );#@492
    for my $part ( @parts ) {
        my $partLnMin = 9999;#@494
        my $partLnMax = 0;#@495
        my $partLn = '?';#@496
        if( $part =~ m/---([0-9]+)(\n|$)/ ) {
            while( $part =~ m/---([0-9]+)(\n|$)/g ) {
                my $aLn = $1;#@501
                if( $aLn > $curLn ) {
                    $curLn = $aLn;#@503
                }
                if( $aLn < $partLnMin ) {
                    $partLnMin = $aLn;#@507
                }
                if( $aLn > $partLnMax ) {
                    $partLnMax = $aLn;#@510
                }
            }
            $part =~ s/---[0-9]+(\n|$)/$1/g;#@513
        }
        if( $partLnMin == $partLnMax ) {
            $partLn = $partLnMin;#@516
        }
        else {
            if( $partLnMin == 9999 && $partLnMax == 0 ) {
                $partLn = $curLn;#@520
            }
            else {
                $partLn = "$partLnMin-$partLnMax";#@523
            }
        }
        if( $part =~ m/^\*</ ) {
            $part = substr( $part, 1 ); # strip off initial *
            my ( $ob, $xml ) = XML::Bare->simple( text => $part );#@528
            $part =~ s/\n/ -- /g; # strip carriage returns so xml can be shown on one line
            $part =~ s/]]>/ ]!]>/g;#@530
            if( $lang eq 'js' ) {
                $out .= "  // XML: $part //\@$partLn\n";#@532
            }
            if( $lang eq 'perl' ) {
                $out .= "  # XML: $part #\@$partLn\n";#@535
            }
            for my $key ( keys %$xml ) {
                my $node = $xml->{ $key };#@538
                $out .= $self->run_tpl_tag( $key, $node, $invar, $outvar );#@539
            }
        }
        else {
            if( $lang eq 'perl' ) {
                $out .= "  $outvar .= " . $self->escape( $part ) .";\n";#@544
            }
            if( $lang eq 'js' ) {
                $out .= "  $outvar += " . $self->escapeForJS( $part ) .";\n";#@547
            }
        }
    }
    if( $outvar eq 'return' ) {
        $out .= "return $outvar;\n";#@553
    }
    return $out;#@557
}
sub setup_tags { #@?
    my $self=shift;
    my $tagsystem = shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@?
                print 'Setting up tags from module '.__FILE__."\n";#@?
                $self->{'lang'} = $lang || 'perl';#@?
            $tagsystem->register_tag(
                name => 'template_tag',
                func => \&tag_template_tag,
                mod => $self,
                stage => 'normal',
                type => 'normal'
            );#@?
            $tagsystem->register_tag(
                name => 'template',
                func => \&tag_template,
                mod => $self,
                stage => 'normal2',
                type => 'raw'
                , alias => 'tpl'
            );#@?
}

1;
