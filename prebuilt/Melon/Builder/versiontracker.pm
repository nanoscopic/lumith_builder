package Melon::Builder::versiontracker;
use File::Slurp ;
use Digest::MD5 qw/md5_hex/;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::versiontracker::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init_inst { #@5
    my $self=shift;
  my %_params = @_;
    my $data = $self->{'data'} = { inFile => [], outFile => [], usedSystem => [] };#@6
    if( exists $_params{'file'} ) {
        my $file = $_params{'file'};#@8
        if( ! -e $file ) {
            print "File $file does not exist\n";#@10
            $data->{'invalid'} = 1;    
            return;#@12
        }
        my ( $ob, $xml ) = XML::Bare->new( file => $file );#@15
        $xml = $xml->{'xml'};#@16
        if( !$xml->{'version'} ) {
            use Data::Dumper;#@18
            print "No version is set in xml; File=$file\nxml=\n".Dumper( $xml );#@19
            $data->{'invalid'} = 1;#@20
            return;#@21
        }
        $self->{'data'} = $xml->{'version'};#@23
    }
}
sub new_inst { #@27

            my $root = shift;
            my $class = ref( $root );
            my %params = @_;
            my $self = bless { %$root }, $class;
            
            $self->init_inst(%params) if( defined( &Melon::Builder::versiontracker::init_inst ) && !$self->{'skipInit'} );
            return $self;}
sub equals { #@31
    my $self=shift;
    my $inst2 = shift;
  my %_params = @_;
    return $self->xmlcompare( $self->{'data'}, $inst2->{'data'} );#@37
}
sub xmlcompare { #@40
    my $self=shift;
    my $n1 = shift;
    my $n2 = shift;
    my $name = shift;
  my %_params = @_;
    $n1 ||= '';#@41
    $n2 ||= '';#@42
    my $t1 = ref( $n1 ) || '';#@43
    my $t2 = ref( $n2 ) || '';#@44
    if( $t1 eq 'ARRAY' && ( scalar @$n1 )==1 ) {
        $n1 = $n1->[0];#@48
        $t1 = ref( $n1 ) || '';#@49
    }
    if( $t1 eq 'ARRAY' && ( scalar @$n1 )==0 ) {
        $n1 = '';#@52
        $t1 = ref( $n1 );#@53
    }
    if( $t2 eq 'ARRAY' && ( scalar @$n2 )==1 ) {
        $n2 = $n2->[0];#@56
        $t2 = ref( $n2 ) || '';#@57
    }
    if( $t2 eq 'ARRAY' && ( scalar @$n2 )==0 ) {
        $n2 = '';#@60
        $t2 = ref( $n2 );#@61
    }
    return 0 if( $n1 && !$n2 );#@64
    return 0 if( $n2 && !$n1 );#@65
    return if( $t1 ne $t2 );#@67
    if( !$t1 ) { # both are text
        return 0 if( $n1 ne $n2 );#@69
    }
    if( $t1 eq 'ARRAY' ) {
        my $len = scalar @$n1;#@72
        for( my $i=0;$i<$len;$i++ ) {
            my $res = $self->xmlcompare( $n1->[$i], $n2->[$i] );#@74
            return 0 if( !$res );#@75
        }
    }
    if( $t1 eq 'HASH' ) {
        my %allkeys;#@80
        for my $key ( keys %$n1 ) {
            $allkeys{ $key } = 1;#@82
        }
        for my $key ( keys %$n2 ) {
            $allkeys{ $key } = 1;#@85
        }
        for my $key ( keys %allkeys ) {
            next if( $key =~ m/^_/ );#@88
            next if( $key eq 'value' );#@89
            next if( $key eq 'outFile' ); # we are only checking inputs
            my $sub1 = $n1->{ $key };#@91
            if( ref( $sub1 ) eq 'HASH' && $sub1->{'value'} ) { $sub1 = $sub1->{'value'}; }
            my $sub2 = $n2->{ $key };#@93
            if( ref( $sub2 ) eq 'HASH' && $sub2->{'value'} ) { $sub2 = $sub2->{'value'}; }
            my $res = $self->xmlcompare( $sub1, $sub2, $key );#@95
            return 0 if( !$res );#@96
        }
    }
    return 1;#@99
}
sub trackUsedSystem { #@102
    my $self=shift;
    my $sysName = shift;
    my $sysBuildId = shift;
    my $sysLang = shift;
    my $caseSysName = shift;
  my %_params = @_;
    push( @{$self->{'data'}{'usedSystem'}}, {
        name     => { value => $sysName   , _att => 1 },
        nameCase => { value => $caseSysName   , _att => 1 },
        build_id => { value => $sysBuildId, _att => 1 },
        lang     => { value => $sysLang   , _att => 1 }
    } );#@108
}
sub trackInputFile { #@111
    my $self=shift;
    my $file = shift;
    my $ident = shift;
  my %_params = @_;
    my $data = read_file( $file );#@112
    my @lines = split("\n",$data);#@113
    my $lineCount = scalar @lines;#@114
    my $md5 = md5_hex( $data );#@115
    push( @{$self->{'data'}{'inFile'}}, { file => { value => $file, _att => 1}, lines => { value => $lineCount, _att => 1 }, md5 => { value => $md5, _att => 1 } } );#@116
}
sub trackVars { #@119
    my $self=shift;
    my $vars = shift;
  my %_params = @_;
    my $data = $self->{'data'};#@120
    for my $key ( keys %$vars ) {
        $data->{ $key } = { value => $vars->{ $key } };#@122
    }
}
sub trackOutputFile { #@126
    my $self=shift;
    my $file = shift;
    my $identy = shift;
  my %_params = @_;
    my $data = read_file( $file );#@127
    my @lines = split("\n",$data);#@128
    my $lineCount = scalar @lines;#@129
    my $md5 = md5_hex( $data );#@130
    push( @{$self->{'data'}{'outFile'}}, { file => { value => $file, _att => 1}, lines => { value => $lineCount, _att => 1 }, md5 => { value => $md5, _att => 1 } } );#@131
}
sub getXML { #@134
    my $self=shift;
  my %_params = @_;
    return XML::Bare::Object::xml(0,{version => $self->{'data'}});#@135
}

1;
