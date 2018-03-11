package Melon::Builder::subwriter;
use Data::Dumper ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                    $self->{'mod_log'} = $params{'mod_log'} || 0;

                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::subwriter::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
    $self->{'lang'} = 'perl';#@6
}
sub setlang { #@9
    my $self=shift;
    my $lang = shift;
  my %_params = @_;
    $self->{'lang'} = $lang;#@10
}
sub write { #@13
    my $self=shift;
    my $subs = shift;
    my $module = shift;
    my $modinfo = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $zCl = '';#@14
    my $tWy = '';#@15
    my $lang = $self->{'lang'};#@16
    my $trace = $mod_builder->{'trace'}; # flag if tracing is enabled
    my %build_globals;#@19
    if( $lang eq 'js' ) {
        my $pkgvar = $mod_builder->{'pkgvar'};#@21
        my $modname = $modinfo->{'name'};#@22
        %build_globals = (
            instanceClass => "MOD_$pkgvar${modname}_inst"
        );#@25
    }
    for my $cursub ( @$subs ) {
        $mod_builder->{'cursub'} = $cursub;#@29
        my $subName  = $cursub->{'name'};#@30
        my $subParts = $cursub->{'parts'};#@31
        my $subLn = $cursub->{'ln'};#@32
        my $subOutput = '';#@34
        my $subOutputTraced = '';#@35
        if( $cursub->{'type'} ne 'init' ) {
            cut_ending_paran( $subParts );#@38
        }
        for my $part ( @$subParts ) {
            next if( !$part );#@42
            my $type = $part->{'type'};#@43
            if( $type eq 'xml' ) {
                print Dumper( $part );#@45
                die "xml parts still present in final stage";#@46
            }
            if( $type eq 'sub' ) {
                my $name = $part->{'name'};#@49
                next;#@50
            }
            if( $type eq 'line' ) {
                my $text = $part->{'text'};#@53
                $text =~ s/\%\{([a-zA-Z0-9_]+)\}/$build_globals{$1}/ge;#@54
                my $traced = $text;#@56
                my $ln = $part->{'ln'} || '?';#@57
                if( $text =~ m/;\n$/ && $ln ) {
                    if( $lang eq 'perl' ) {
                        $text =~ s/\n$/#\@$ln\n/;#@61
                    }
                    if( $lang eq 'js' ) {
                        $text =~ s|\n$|//\@$ln\n|;#@64
                    }
                }
                $traced =~ s/\n$/#\@$ln\n/;#@67
                $subOutput .= $text;#@69
                $subOutputTraced .= $traced;#@70
            }
        }
        if( $cursub->{'type'} ne 'init' ) {
            my $subEnd = "}\n";#@76
            my $subStart = $self->run_sub(
                modXml => $module,
                metacode => $cursub,
                modInfo => $modinfo,
                ln => $subLn,
                trace => $trace
            );#@83
            if( $lang eq 'perl' ) {
                $subOutput = "sub $subName { #\@$subLn\n" . $subStart . $subOutput . $subEnd;#@86
                $subOutputTraced = "sub $subName { #\@$subLn\n" . $subStart . $subOutputTraced . $subEnd;#@87
            }
            if( $lang eq 'js' ) {
                my $pkgvar = $mod_builder->{'pkgvar'};#@90
                my $modname = $modinfo->{'name'};#@91
                $subOutput = "MOD_$pkgvar$modname.prototype.$subName = function" . $subStart . $subOutput . $subEnd;#@92
                $subOutputTraced = "MOD_$pkgvar$modname.prototype.$subName = function" . $subStart . $subOutput . $subEnd;#@93
            }
        }
        $self->reset_sub();#@97
        my $dests = $self->{'sym_dest'};#@98
        while( $subOutput =~ m/[^\\\$]\$([a-zA-Z]{3})[^[a-zA-Z0-9_]/g ) {
            $dests->{ $1 } = 1;#@100
        }
        $subOutput =~ s/([^\\])\$\$([a-zA-Z0-9_]+)/assign_dest( $self, $1, $2 )/ge;#@103
        $zCl .= $subOutput;#@105
        $tWy .= $subOutputTraced;#@106
    }
    return ( $zCl, $tWy );#@108
}
sub cut_ending_paran {
    my $parts = shift;#@112
    my $i = 0;#@113
    my $ok = 0;#@114
    return if( !$parts );#@115
    for( $i=((scalar @$parts)-1); $i >= 0; $i-- ) {
        my $part = $parts->[ $i ];#@117
        my $type = $part->{'type'};#@118
        if( $type eq 'line' ) {
            my $text = $part->{'text'};#@120
            if( $text =~ m/^\s*\}\s*$/ ) {
                $ok = 1;#@122
                last;#@123
            }
        }
    }
    die if( !$ok );#@127
    delete $parts->[ $i ];#@128
}
sub reset_sub { #@131
    my $self=shift;
  my %_params = @_;
    $self->{'sym_map'} = {};#@132
    $self->{'sym_dest'} = {};#@133
    my $test = 2;#@134
    my $x = "a\$$test";#@135
}
sub assign_dest { #@138
    my $self=shift;
    my $char = shift;
    my $in = shift;
  my %_params = @_;
    my $map = $self->{'sym_map'};#@139
    if( my $sym = $map->{$in} ) {
        return $char.'$'.$sym;#@141
    }
    my $dests = $self->{'sym_dest'};#@143
    for( my $i=0;$i<20;$i++ ) {
        my $newsym = $self->rand_sym();#@145
        next if( $dests->{$newsym} );#@146
        $dests->{$newsym} = 1;#@147
        $map->{$in} = $newsym;#@148
        return $char.'$'.$newsym;#@149
    }
    if( $dests->{$in} ) {
        die "Cannot find a symbol to assign for obfuscation and the original symbol has been used";#@152
    }
    return $char.'$'.$in;#@154
}
sub rand_sym { #@157
    my $self=shift;
  my %_params = @_;
    return chr( ord('a')+rand(26) ).chr( ord('A')+rand(26) ).chr( ord('a')+rand(26) );#@158
}
sub run_sub { #@162
    my $self=shift;
  my %_params = @_;
    my $mod_log = $self->{'mod_log'};
    my $module = $_params{'modXML'};#@163
    my $sub = $_params{'metacode'};#@164
    my $modInfo = $_params{'modInfo'};#@165
    my $ln = $_params{'ln'};#@166
    my $trace = $_params{'trace'};#@167
    my $lang = $self->{'lang'};#@169
    my $subName = $sub->{'name'};#@170
    my $modName = $modInfo->{'name'};#@171
    my $params = $sub->{'params'};#@173
    my $out = "";#@175
    if( $lang eq 'perl' ) {
        $out .= "    my \$self=shift;\n" if( $subName ne 'new_inst' );#@177
        for my $param ( @$params ) {
            $out .= "    my \$$param = shift;\n";#@180
        }
        $out .= "  my \%_params = \@_;\n" if( $subName ne 'new_inst' );#@183
        if( $trace ) {
            $out .= "  my \$_trId = \$mod_log->{'trId'}++;\n";#@185
            $out .= "  \$mod_log->tr_subentry( \$_trId, '$modName', '$subName', \\\%_params );\n";#@186
        }
    }
    if( $lang eq 'js' ) {
        $out .= "(";#@191
        if( @$params ) {
            for my $param ( @$params ) {
                $out .= "\$$param,";#@195
            }
        }
        if( $subName ne 'new_inst' ) {
            $out .= "\$params) {\n" ;#@201
        }
        else {
            $out .= ") { //\@$ln\n" ;#@204
        }
    }
    my $vars = $sub->{'vars'};#@210
    my %doneVars;#@213
    for my $var ( @$vars ) {
        my $fromself = $var->{'self'};#@216
        next if( $doneVars{ $fromself } );#@217
        $doneVars{ $fromself } = 1;#@218
        if( $lang eq 'perl' ) {
            if( $fromself ) {
                my $tovar = $var->{'var'} || $fromself;#@221
                $out .= "    my \$$tovar = \$self->{'$fromself'};\n";#@222
            }
            my $fromname = $var->{'name'};#@224
            if( $fromname ) {
                my $tovar = $var->{'var'} || $fromname;#@226
                $out .= "    my \$$tovar = \$_params{'$fromname'};\n";#@227
            }
        }
        if( $lang eq 'js' ) {
            if( $fromself ) {
                my $tovar = $var->{'var'} || $fromself;#@232
                $out .= "    var \$$tovar = this.$fromself;\n";#@233
            }
            my $fromname = $var->{'name'};#@235
            if( $fromname ) {
                my $tovar = $var->{'var'} || $fromname;#@237
                $out .= "    var \$$tovar = \$_params.$fromname;\n";#@238
            }
        }
    }
    return $out;#@243
}

1;
