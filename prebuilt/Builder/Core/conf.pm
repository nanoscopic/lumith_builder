package Builder::Core::conf;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::conf::init ) && !$self->{'skipInit'} );
                return $self;
            }sub doConf { #@5
    my $self=shift;
  my %_params = @_;
    my $modInstances = $_params{'modInstances'};#@6
    my $mods = $_params{'mods'};#@7
    my $conf = $_params{'conf'};#@8
    my $hasConf = $_params{'hasConf'};#@9
    my %doneConf;#@15
    my %depHash;#@16
    for my $modname ( @$mods ) {
        my $depinfo = $depHash{ $modname } = {};#@18
        my $modConf = $conf->{ $modname };#@19
        $self->walkConf( $depinfo, $modConf );#@20
    }
    my $passes = $self->resolvePasses( \%depHash, $mods );#@23
    for my $pass ( @$passes ) {
        my $passMods = $pass->{'mods'};#@25
        for my $modname ( keys %$passMods ) {
            my $modConf = $conf->{ $modname };#@27
            $self->walkConfModify( $conf, $modConf );#@28
        }
    }
    for my $modname ( @$mods ) {
        if( $hasConf->{ $modname } ) {
            $modInstances->{ $modname }->conf( $conf->{ $modname } );#@34
        }
    }
}
sub resolvePasses { #@39
    my $self=shift;
    my $depHash = shift;
    my $mods = shift;
  my %_params = @_;
    my %finishedMods;#@40
    my @passes;#@41
    my %curpass;#@42
    for( my $i=0;$i<10;$i++ ) {
       my $passMods = $curpass{'mods'} = {}; # mods on this pass
       for my $modname ( @$mods ) {
           my $depsDone = 1;#@47
           my $depinfo = $depHash->{ $modname };#@48
           for my $key ( keys %$depinfo ) {
               if( !$finishedMods{ $key } ) {
                   $depsDone = 0;#@51
                   last;#@52
               }
           }
           if( $depsDone ) {
               $passMods->{ $modname } = 1;#@57
           }
       }
       last if( !%$passMods ); # nothing in this pass; we are done
       for my $modname ( keys %$passMods ) {
           $finishedMods{ $modname } = 1;#@62
       }
       push( @passes, \%curpass );#@64
    }
    return \@passes;#@66
}
sub walkConf { #@69
    my $self=shift;
    my $depinfo = shift;
    my $conf = shift;
  my %_params = @_;
    my $rType = ref( $conf );#@70
    return if( !$rType || ( $rType ne 'HASH' && $rType ne 'ARRAY' ) );#@71
    if( $rType eq 'ARRAY' ) {
        for my $aConf ( @$conf ) {
            $self->walkConf( $depinfo, $aConf );#@74
        }
        return;#@76
    }
    for my $key ( keys %$conf ) {
        my $val = $conf->{ $key };#@80
        if( ref( $val ) ) {
            $self->walkConf( $depinfo, $val );#@82
        }
        else {
            if( $val =~ m/\*\{/ ) { # has a variable; check it
                $val =~ s/\*\{mod_([a-zA-Z0-9_])\.([a-zA-Z0-9.]+)\}/$self->noteDep( $depinfo, $1, $2 )/ge; # global eval
            }
        }
    }
}
sub walkConfModify { #@93
    my $self=shift;
    my $allConf = shift;
    my $conf = shift;
  my %_params = @_;
    my $rType = ref( $conf );#@94
    return if( !$rType || ( $rType ne 'HASH' && $rType ne 'ARRAY' ) );#@95
    if( $rType eq 'ARRAY' ) {
        for my $aConf ( @$conf ) {
            $self->walkConfModify( $allConf, $aConf );#@98
        }
        return;#@100
    }
    for my $key ( keys %$conf ) {
        my $val = $conf->{ $key };#@104
        if( ref( $val ) ) {
            $self->walkConfModify( $allConf, $val );#@106
        }
        else {
            if( $val =~ m/\*\{/ ) { # has a variable; check it
                $val =~ s/\*\{mod_([a-zA-Z0-9_])\.([a-zA-Z0-9.]+)\}/$self->fillDep( $allConf, $1, $2 )/ge; # global eval
                $conf->{ $key } = $val;    
            }
        }
    }
}
sub noteDep { #@118
    my $self=shift;
    my $depinfo = shift;
    my $modname = shift;
    my $confPath = shift;
  my %_params = @_;
    $depinfo->{ $modname } = 1;#@119
    return "*{mod_$modname.$confPath}"; # return the same thing so as not to alter
}
sub fillDep { #@123
    my $self=shift;
    my $allConf = shift;
    my $modname = shift;
    my $confPath = shift;
  my %_params = @_;
    my $modConf = $allConf->{ $modname };#@124
    die "Cannot fetch conf for $modname - expression=mod_$modname.$confPath" if( !$modConf );#@125
    my @pathParts = split( '.', $confPath );#@126
    my $confLoc = $modConf;#@127
    for my $part ( @pathParts ) {
        $confLoc = $confLoc->{ $part };#@129
        if( !$confLoc ) {
            die "Cannot fetch conf for $modname - expression=mod_$modname.$confPath - dead end";#@131
        }
    }
    if( ref( $confLoc ) ) {
        use Data::Dumper;#@136
        print Dumper( $confLoc );#@137
        die "Conf for $modname - expression=mod_$modname.$confPath - not a string";#@138
    }
    return $confLoc;#@140
}

1;
