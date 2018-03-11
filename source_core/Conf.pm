# Copyright (C) 2018 David Helkowski

<header/>

<construct/>

sub doConf {
    <param name="modInstances"/>
    <param name="mods"/>
    <param name="conf"/>
    <param name="hasConf"/>
    
    # Analyze conf hash for interdependencies
    # Resolve those dependencies and fill them in via templates
    # Run the conf functions for each module that has one
    
    my %doneConf;
    my %depHash;
    for my $modname ( @$mods ) {
        my $depinfo = $depHash{ $modname } = {};
        my $modConf = $conf->{ $modname };
        $self->walkConf( $depinfo, $modConf );
    }
    
    my $passes = $self->resolvePasses( \%depHash, $mods );
    for my $pass ( @$passes ) {
        my $passMods = $pass->{'mods'};
        for my $modname ( keys %$passMods ) {
            my $modConf = $conf->{ $modname };
            $self->walkConfModify( $conf, $modConf );
        }
    }
    
    for my $modname ( @$mods ) {
        if( $hasConf->{ $modname } ) {
            $modInstances->{ $modname }->conf( $conf->{ $modname } );
        }
    }
}

sub resolvePasses( depHash, mods ) {
    my %finishedMods;
    my @passes;
    my %curpass;
    for( my $i=0;$i<10;$i++ ) {
       my $passMods = $curpass{'mods'} = {}; # mods on this pass
       
       for my $modname ( @$mods ) {
           my $depsDone = 1;
           my $depinfo = $depHash->{ $modname };
           for my $key ( keys %$depinfo ) {
               if( !$finishedMods{ $key } ) {
                   $depsDone = 0;
                   last;
               }
           }
           if( $depsDone ) {
               # insert into current pass
               $passMods->{ $modname } = 1;
           }
       }
       last if( !%$passMods ); # nothing in this pass; we are done
       for my $modname ( keys %$passMods ) {
           $finishedMods{ $modname } = 1;
       }
       push( @passes, \%curpass );
    }
    return \@passes;
}

sub walkConf( depinfo, conf ) {
    my $rType = ref( $conf );
    return if( !$rType || ( $rType ne 'HASH' && $rType ne 'ARRAY' ) );
    if( $rType eq 'ARRAY' ) {
        for my $aConf ( @$conf ) {
            $self->walkConf( $depinfo, $aConf );
        }
        return;
    }
    # rType is Hash at this point
    for my $key ( keys %$conf ) {
        my $val = $conf->{ $key };
        if( ref( $val ) ) {
            $self->walkConf( $depinfo, $val );
        }
        else {
            # not a ref, must be a string
            if( $val =~ m/\*\{/ ) { # has a variable; check it
                $val =~ s/\*\{mod_([a-zA-Z0-9_])\.([a-zA-Z0-9.]+)\}/$self->noteDep( $depinfo, $1, $2 )/ge; # global eval
            }
        }
    }
}

sub walkConfModify( allConf, conf ) {
    my $rType = ref( $conf );
    return if( !$rType || ( $rType ne 'HASH' && $rType ne 'ARRAY' ) );
    if( $rType eq 'ARRAY' ) {
        for my $aConf ( @$conf ) {
            $self->walkConfModify( $allConf, $aConf );
        }
        return;
    }
    # rType is Hash at this point
    for my $key ( keys %$conf ) {
        my $val = $conf->{ $key };
        if( ref( $val ) ) {
            $self->walkConfModify( $allConf, $val );
        }
        else {
            # not a ref, must be a string
            if( $val =~ m/\*\{/ ) { # has a variable; check it
                $val =~ s/\*\{mod_([a-zA-Z0-9_])\.([a-zA-Z0-9.]+)\}/$self->fillDep( $allConf, $1, $2 )/ge; # global eval
                $conf->{ $key } = $val;    
            }
        }
    }
}

sub noteDep( depinfo, modname, confPath ) {
    $depinfo->{ $modname } = 1;
    return "*{mod_$modname.$confPath}"; # return the same thing so as not to alter
}

sub fillDep( allConf, modname, confPath ) {
    my $modConf = $allConf->{ $modname };
    die "Cannot fetch conf for $modname - expression=mod_$modname.$confPath" if( !$modConf );
    my @pathParts = split( '.', $confPath );
    my $confLoc = $modConf;
    for my $part ( @pathParts ) {
        $confLoc = $confLoc->{ $part };
        if( !$confLoc ) {
            die "Cannot fetch conf for $modname - expression=mod_$modname.$confPath - dead end";
        }
    }
    if( ref( $confLoc ) ) {
        # not good; should be a string
        use Data::Dumper;
        print Dumper( $confLoc );
        die "Conf for $modname - expression=mod_$modname.$confPath - not a string";
    }
    return $confLoc;
}