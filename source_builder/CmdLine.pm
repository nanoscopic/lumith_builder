# Copyright (C) 2018 David Helkowski

<header/>
<construct/>

psub parse_args {
    my $cmdArgs = shift;
    my $argLine = join( ' ', @$cmdArgs );
    my $res = {};
    $argLine =~ s/--([a-zA-Z0-9_]+)/op_flag($1)/ge; # find and replace flags to have a value
    $argLine =~ s/--([a-zA-Z0-9_]+) ([^" ]+)/op_space($1,$2)/ge; # fix space delimited arguments
    
    #print "Argument line: $argLine\n";
    $argLine =~ s/--([a-zA-Z0-9_]+)="(.+?)"/named_arg($res,$1,$2)/ge;
    return $res;
}

psub named_arg {
    my ( $res, $name, $val ) = @_;
    if( $name eq 'skipmod' ) {
        my $skip = $res->{'skipModules'} ||= [];
        push( @$skip, $val );
    }
    if( $name eq 'force' ) {
        $res->{'forceRebuild'} = 1;
    }
    if( $name eq 'trace' ) {
        $res->{'trace'} = 1;
    }
    return '';
}

psub op_flag {
    my $name = shift;
    my %flags = (
        force => 1,
        trace => 1,
        );
    if( $flags{$name} ) {
        return "--$name=\"1\"";
    }
    return "--$name";
}

psub op_space {
    my ( $name, $val ) = @_;
    return "--$name=\"$val\"";
}