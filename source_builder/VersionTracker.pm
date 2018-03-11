# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub init_inst {
    my $data = $self->{'data'} = { inFile => [], outFile => [], usedSystem => [] };
    if( exists $_params{'file'} ) {
        my $file = $_params{'file'};
        if( ! -e $file ) {
            print "File $file does not exist\n";
            $data->{'invalid'} = 1;    
            return;
        }
        
        my ( $ob, $xml ) = XML::Bare->new( file => $file );
        $xml = $xml->{'xml'};
        if( !$xml->{'version'} ) {
            use Data::Dumper;
            print "No version is set in xml; File=$file\nxml=\n".Dumper( $xml );
            $data->{'invalid'} = 1;
            return;
        }
        $self->{'data'} = $xml->{'version'};
    }
}

sub new_inst {
    <new_inst />
}

sub equals( inst2 ) {
    #print "Comparing the following two:\n";
    #se Data::Dumper;
    #print Dumper( $self->{'data'} );
    #print Dumper( $inst2->{'data'} );
    
    return $self->xmlcompare( $self->{'data'}, $inst2->{'data'} );
}

sub xmlcompare( n1, n2, name ) {
    $n1 ||= '';
    $n2 ||= '';
    my $t1 = ref( $n1 ) || '';
    my $t2 = ref( $n2 ) || '';
    
    # Hacks to handle corner cases
    if( $t1 eq 'ARRAY' && ( scalar @$n1 )==1 ) {
        $n1 = $n1->[0];
        $t1 = ref( $n1 ) || '';
    }
    if( $t1 eq 'ARRAY' && ( scalar @$n1 )==0 ) {
        $n1 = '';
        $t1 = ref( $n1 );
    }
    if( $t2 eq 'ARRAY' && ( scalar @$n2 )==1 ) {
        $n2 = $n2->[0];
        $t2 = ref( $n2 ) || '';
    }
    if( $t2 eq 'ARRAY' && ( scalar @$n2 )==0 ) {
        $n2 = '';
        $t2 = ref( $n2 );
    }
    
    return 0 if( $n1 && !$n2 );
    return 0 if( $n2 && !$n1 );
    
    return if( $t1 ne $t2 );
    if( !$t1 ) { # both are text
        return 0 if( $n1 ne $n2 );
    }
    if( $t1 eq 'ARRAY' ) {
        my $len = scalar @$n1;
        for( my $i=0;$i<$len;$i++ ) {
            my $res = $self->xmlcompare( $n1->[$i], $n2->[$i] );
            return 0 if( !$res );
        }
    }
    if( $t1 eq 'HASH' ) {
        # assuming here that the keys are the same; fine for this purpose but not general...
        my %allkeys;
        for my $key ( keys %$n1 ) {
            $allkeys{ $key } = 1;
        }
        for my $key ( keys %$n2 ) {
            $allkeys{ $key } = 1;
        }
        for my $key ( keys %allkeys ) {
            next if( $key =~ m/^_/ );
            next if( $key eq 'value' );
            next if( $key eq 'outFile' ); # we are only checking inputs
            my $sub1 = $n1->{ $key };
            if( ref( $sub1 ) eq 'HASH' && $sub1->{'value'} ) { $sub1 = $sub1->{'value'}; }
            my $sub2 = $n2->{ $key };
            if( ref( $sub2 ) eq 'HASH' && $sub2->{'value'} ) { $sub2 = $sub2->{'value'}; }
            my $res = $self->xmlcompare( $sub1, $sub2, $key );
            return 0 if( !$res );
        }
    }
    return 1;
}

sub trackUsedSystem( sysName, sysBuildId, sysLang, caseSysName ) {
    push( @{$self->{'data'}{'usedSystem'}}, {
        name     => { value => $sysName   , _att => 1 },
        nameCase => { value => $caseSysName   , _att => 1 },
        build_id => { value => $sysBuildId, _att => 1 },
        lang     => { value => $sysLang   , _att => 1 }
    } );
}

sub trackInputFile( file, ident ) {
    my $data = read_file( $file );
    my @lines = split("\n",$data);
    my $lineCount = scalar @lines;
    my $md5 = md5_hex( $data );
    push( @{$self->{'data'}{'inFile'}}, { file => { value => $file, _att => 1}, lines => { value => $lineCount, _att => 1 }, md5 => { value => $md5, _att => 1 } } );
}

sub trackVars( vars ) {
    my $data = $self->{'data'};
    for my $key ( keys %$vars ) {
        $data->{ $key } = { value => $vars->{ $key } };
    }
}

sub trackOutputFile( file, identy ) {
    my $data = read_file( $file );
    my @lines = split("\n",$data);
    my $lineCount = scalar @lines;
    my $md5 = md5_hex( $data );
    push( @{$self->{'data'}{'outFile'}}, { file => { value => $file, _att => 1}, lines => { value => $lineCount, _att => 1 }, md5 => { value => $md5, _att => 1 } } );
}

sub getXML {
    return XML::Bare::Object::xml(0,{version => $self->{'data'}});
}