package Builder::Core2::xml;
use Carp ;
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
                $self->init(%params) if( defined( &Builder::Core2::xml::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
    $self->{'schemas'} = {};#@6
}
sub tag_xml_schema { #@9
    my $self=shift;
  my %_params = @_;
    my $tag = $_params{'metacode'};#@11
    my $xmltext = $tag->{'raw'};#@13
    my $name = $tag->{'name'};#@14
    my ( $ob, $xml ) = XML::Bare->new( text => $xmltext );#@15
    $self->{'schemas'}{ $name } = $xml;#@16
    return '';#@17
}
sub tag_xml_db { #@20
    my $self=shift;
  my %_params = @_;
    my $mod_xml_ = $self->{'mod_xml_'};
    my $tag = $_params{'metacode'};#@22
    my $name = $tag->{'name'};#@25
    my $schema = $tag->{'schema'};#@26
    my $schemas = $self->{'schemas'};#@27
    my $var = $tag->{'var'} || $name;#@28
    my $ob;#@29
    my $xml = $schemas->{ $schema };#@30
    if( !$xml ) {
        ( $ob, $xml ) = XML::Bare->new( file => $schema );#@32
    }
    my $actions = $self->gencode_at_level( "xml_$name", 1, $xml );#@34
    if( $tag->{'file'} ) {
        my $file = $tag->{'file'};#@38
        push( @$actions, {
            action => 'add_sub_text',
            sub => 'init',
            text => "\$self->{'xml_db_$name'} = \$mod_xml_$name->new_inst( file => $file );\n"
        }, {
            action => 'add_text',
            text => "\$$var = \$self->{'xml_db_$name'};\n"
        } );#@46
    }
    my $xmlText = '';#@48
    if( $tag->{'data'} ) {
        $xmlText = XML::Bare::Object::xml( 0, $tag->{'data'} );#@50
    }
    elsif( $tag->{'raw'} ) {
        $xmlText = $tag->{'raw'};#@53
    }
    if( $xmlText ) {
        $xmlText =~ s/\n/\\n/g;#@56
        $xmlText =~ s/"/\\"/g;#@57
        push( @$actions, {
            action => 'add_sub_text',
            sub => 'init',
            text => "my \$data_xml_$name = \"$xmlText\";\
    \$self->{'xml_db_$name'} = \$mod_xml_$name->new_inst( text => \$data_xml_$name );\n"
        }, {
            action => 'add_text',
            text => "my \$$var = \$self->{'xml_db_$name'};\n"
        } );#@66
    }
    return $actions;#@69
}
sub gencode_at_level { #@72
    my $self=shift;
    my $path = shift;
    my $isRoot = shift;
    my $xml = shift;
  my %_params = @_;
    my @actions;#@73
    my $functionText = '';#@75
    my $modsText = '';#@76
    if( !ref($xml) || ref($xml) ne 'HASH' ) {
        use Data::Dumper;#@79
        confess "$xml is not a ref. xml=" . Dumper( $xml );#@80
    }
    for my $keySpec ( keys %$xml ) {
        next if( $keySpec =~ m/^_/ );#@83
        next if( $keySpec eq 'value' );#@84
        my $min = 0;#@86
        my $max = 0;#@87
        my $keyName = '';#@88
        if( $keySpec =~ m/(.+)\{([0-9]+),([0-9]+)\}$/ ) { # node{1,3}
            $keyName = $1;#@90
            $min = $2;#@91
            $max = $3;#@92
        }
        elsif( $keySpec =~ m/(.+)\*$/ ) { # node* ( 0 or more )
            $keyName = $1;#@95
            $min = 0;#@96
            $max = 9999;#@97
        }
        elsif( $keySpec =~ m/(.+)\+$/ ) { # node+ ( 1 or more )
            $keyName = $1;#@100
            $min = 1;#@101
            $max = 9999;#@102
        }
        elsif( $keySpec =~ m/(.+)\?$/ ) { # node? ( 0 or 1 )
            $keyName = $1;#@105
            $min = 0;#@106
            $max = 1;#@107
        }
        else {
            $keyName = $keySpec;#@110
            $min = 1;#@111
            $max = 1;#@112
        }
        my $subSpec = $xml->{ $keySpec };#@115
        if( ref( $subSpec ) eq 'ARRAY' ) {
            my $first = $subSpec->[0];#@118
            my $isObj = has_children( $first );#@119
            if( $isObj ) {
                my $statics = $self->find_shared_static_keys( $subSpec );#@122
                my $u = $self->find_unique_statics( $subSpec, $statics );#@123
                my $branchKey = $u->[0]; # use the first unique static key; is good enough
                my %branchHash;#@126
                for my $oneSpec ( @$subSpec ) {
                    my $branchVal = $oneSpec->{ $branchKey }{'value'};#@128
                    my $branchModName = "xml_${path}_${keyName}_${branchKey}_$branchVal";#@129
                    $branchHash{ $branchVal } = $branchModName;#@130
                    $modsText .= "<mod name='$branchModName' />\n";#@131
                    push( @actions, @{$self->gencode_at_level( $branchModName, 0, $oneSpec )} );#@132
                }
                if( $max > 1 ) {
                    $functionText .= $self->gen_multi_access( $path, $keyName, $subSpec, $isObj, $branchKey, \%branchHash );#@136
                }
                else {
                    $functionText .= $self->gen_single_access( $path, $keyName, $subSpec, $isObj, $branchKey, \%branchHash );#@139
                }
            }
            else { # multiple accepptable values / expressions
            }
        }
        else {
            my $isObj = has_children( $subSpec );#@147
            if( $max > 1 ) {
                $functionText .= $self->gen_multi_access( $path, $keyName, $subSpec, $isObj );#@149
            }
            else {
                $functionText .= $self->gen_single_access( $path, $keyName, $subSpec, $isObj );#@152
            }
            if( $isObj ) {
                push( @actions, @{$self->gencode_at_level( "${path}_$keyName", 0, $subSpec )} );#@156
                $modsText .= "<mod name='${path}_$keyName' />\n";#@157
            }
        }
    }
my $moduleText = '';
  $moduleText .= ''."\n".'        <header/>'."\n".'        <construct>'."\n".'          ';
  # XML: <var name='modsText'/> #@164
  $moduleText .= $modsText;
  $moduleText .= ''."\n".'        </construct>'."\n".'        '."\n".'        sub new_inst {'."\n".'            <new_inst />'."\n".'        }'."\n".'        '."\n".'        ';
  # XML: <var name='functionText'/> #@171
  $moduleText .= $functionText;
  $moduleText .= '';#@163
    if( $isRoot ) {
  $moduleText .= ''."\n".'            sub init_inst {'."\n".'                <param name=\'file\' />'."\n".'                <param name=\'text\' />'."\n".'                my $a;'."\n".'                my $b;'."\n".'                if( $file ) {'."\n".'                    ( $a, $b ) = XML::Bare->new( file => $file );'."\n".'                }'."\n".'                if( $text ) {'."\n".'                    ( $a, $b ) = XML::Bare->new( text => $text );'."\n".'                }'."\n".'                $self->{\'node\'} = $b;'."\n".'            }';#@177
    }
    else {
  $moduleText .= ''."\n".'            sub init_inst {'."\n".'                <param name=\'node\' />'."\n".'                $self->{\'node\'} = $node;'."\n".'            }';#@194
    }
  $moduleText .= ''."\n".'        sub value {'."\n".'            return $self->{\'node\'}{\'value\'};'."\n".'        }';#@202
    my $filename = $path;#@207
    $filename =~ s/^xml_//;#@208
    push( @actions, {
        action => "create_module",
        file => "gen_mod/XML/$filename.pm",
        name => "$path",
        text => $moduleText,
        multiple => 1
    } );#@215
    return \@actions;#@216
}
sub find_unique_statics { #@219
    my $self=shift;
    my $specs = shift;
    my $statics = shift;
  my %_params = @_;
    my @unique;#@220
    for my $static ( @$statics ) {
        push( @unique, $static ) if( $self->is_static_unique( $specs, $static ) );#@222
    }
    return \@unique;#@224
}
sub is_static_unique { #@227
    my $self=shift;
    my $specs = shift;
    my $key = shift;
  my %_params = @_;
    my %counts;#@228
    for my $spec ( @$specs ) {
        my $val = $spec->{ $key }{'value'} || '--undef--';#@230
        $counts{ $val }++;#@231
        if( $counts{ $val } > 1 ) {
            return 0;#@233
        }
    }
    return 1;#@236
}
sub find_shared_static_keys { #@239
    my $self=shift;
    my $specs = shift;
  my %_params = @_;
    my %static_counts;#@240
    my $numspecs = scalar @$specs;#@242
    for my $spec ( @$specs ) {
        my $statics = $self->get_static_keys( $spec );#@247
        for my $static ( @$statics ) {
            $static_counts{ $static }++;#@251
        }
    }
    my @statics;#@256
    for my $key ( keys %static_counts ) {
        my $count = $static_counts{ $key };#@258
        push( @statics, $key ) if( $count == $numspecs );#@259
    }
    return \@statics;#@262
}
sub get_static_keys { #@265
    my $self=shift;
    my $spec = shift;
  my %_params = @_;
    my @statics;#@266
    for my $key ( keys %$spec ) {
        next if( $key =~ m/^_/ );#@268
        next if( $key eq 'value' );#@269
        my $sub = $spec->{ $key };#@270
        push( @statics, $key ) if( !has_children( $key ) );#@271
    }
    return \@statics;#@273
}
sub has_children {
    my $node = shift;#@277
    return 0 if( !ref( $node ) );#@278
    for my $key ( keys %$node ) {
        next if( $key =~ m/^_/ );#@281
        next if( $key eq 'value' );#@282
        return 1;#@283
    }
    return 0;#@285
}
sub gen_multi_access { #@288
    my $self=shift;
    my $path = shift;
    my $name = shift;
    my $node = shift;
    my $isObj = shift;
    my $branchKey = shift;
    my $branchHash = shift;
  my %_params = @_;
    my $mod_templates = $self->{'mod_templates'};
my $code = '';
  $code .= ''."\n".'        sub get_';
  # XML: <var name='name'/> #@290
  $code .= $name;
  $code .= 's {'."\n".'            my $nodes = forcearray( $self->{\'node\'}{';
  # XML: <varq name='name'/> #@290
  $code .= $mod_templates->escape( $name );
  $code .= '} );';#@290
    if( $isObj ) {
  $code .= ''."\n".'            my @res;'."\n".'            for my $node ( @$nodes ) {';#@296
        if( $branchKey ) {
  $code .= ''."\n".'                my $compare = $node->{';
  # XML: <varq name='branchKey'/> #@302
  $code .= $mod_templates->escape( $branchKey );
  $code .= '}{\'value\'};';#@302
            for my $keyVal ( keys %$branchHash ) {
                my $mod = $branchHash->{ $keyVal };#@306
  $code .= ''."\n".'                    if( $compare eq ';
  # XML: <varq name='keyVal'/> #@308
  $code .= $mod_templates->escape( $keyVal );
  $code .= ' ) {'."\n".'                        push( @res, $mod_';
  # XML: <var name='mod'/> #@308
  $code .= $mod;
  $code .= '->new_inst( node => $node );'."\n".'                        next;'."\n".'                    }';#@308
            }
        }
        else {
  $code .= ''."\n".'                push( @res, $mod_';
  # XML: <var name='path'/> #@317
  $code .= $path;
  $code .= '_';
  # XML: <var name='name'/> #@317
  $code .= $name;
  $code .= '->new_inst( node => $node );';#@317
        }
  $code .= ''."\n".'            }'."\n".'            return \\@res;';#@321
    }
    else {
  $code .= ''."\n".'            return $nodes;';#@327
    }
    $code .= "\n}\n";#@330
    return $code;#@332
}
sub gen_single_access { #@335
    my $self=shift;
    my $path = shift;
    my $name = shift;
    my $node = shift;
    my $isObj = shift;
    my $branchKey = shift;
    my $branchHash = shift;
  my %_params = @_;
    my $mod_templates = $self->{'mod_templates'};
my $code = '';
  $code .= ''."\n".'        sub get_';
  # XML: <var name='name'/> #@337
  $code .= $name;
  $code .= ' {'."\n".'            my $node = $self->{\'node\'}{';
  # XML: <varq name='name'/> #@337
  $code .= $mod_templates->escape( $name );
  $code .= '};';#@337
    if( $isObj ) {
        if( $branchKey ) {
  $code .= ''."\n".'                my $compare = $node->{';
  # XML: <varq name='branchKey'/> #@344
  $code .= $mod_templates->escape( $branchKey );
  $code .= '}{\'value\'};';#@344
            for my $keyVal ( keys %$branchHash ) {
                my $mod = $branchHash->{ $keyVal };#@348
  $code .= ''."\n".'                    if( $compare eq ';
  # XML: <varq name='keyVal'/> #@350
  $code .= $mod_templates->escape( $keyVal );
  $code .= ' ) {'."\n".'                        return $mod_';
  # XML: <var name='mod'/> #@350
  $code .= $mod;
  $code .= '->new_inst( node => $node );'."\n".'                    }';#@350
            }
        }
        else {
  $code .= ''."\n".'               return $mod_';
  # XML: <var name='path'/> #@358
  $code .= $path;
  $code .= '_';
  # XML: <var name='name'/> #@358
  $code .= $name;
  $code .= '->new_inst( node => $node );';#@358
        }
        $code .= "\n}\n";#@361
    }
    else {
        $code .= "return \$node->{'value'};\n}\n";#@364
    }
    return $code;#@367
}
sub setup_tags { #@?
    my $self=shift;
    my $tagsystem = shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@?
                print 'Setting up tags from module '.__FILE__."\n";#@?
                $self->{'lang'} = $lang || 'perl';#@?
            $tagsystem->register_tag(
                name => 'xml_schema',
                func => \&tag_xml_schema,
                mod => $self,
                stage => 'normal',
                type => 'raw'
            );#@?
            $tagsystem->register_tag(
                name => 'xml_db',
                func => \&tag_xml_db,
                mod => $self,
                stage => 'normal',
                type => 'raw'
            );#@?
}

1;
