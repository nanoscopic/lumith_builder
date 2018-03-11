package Melon::Builder::cmdline;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::cmdline::init ) && !$self->{'skipInit'} );
                return $self;
            }sub parse_args {
    my $cmdArgs = shift;#@5
    my $argLine = join( ' ', @$cmdArgs );#@6
    my $res = {};#@7
    $argLine =~ s/--([a-zA-Z0-9_]+)/op_flag($1)/ge; # find and replace flags to have a value
    $argLine =~ s/--([a-zA-Z0-9_]+) ([^" ]+)/op_space($1,$2)/ge; # fix space delimited arguments
    $argLine =~ s/--([a-zA-Z0-9_]+)="(.+?)"/named_arg($res,$1,$2)/ge;#@12
    return $res;#@13
}
sub named_arg {
    my ( $res, $name, $val ) = @_;#@17
    if( $name eq 'skipmod' ) {
        my $skip = $res->{'skipModules'} ||= [];#@19
        push( @$skip, $val );#@20
    }
    if( $name eq 'force' ) {
        $res->{'forceRebuild'} = 1;#@23
    }
    if( $name eq 'trace' ) {
        $res->{'trace'} = 1;#@26
    }
    return '';#@28
}
sub op_flag {
    my $name = shift;#@32
    my %flags = (
        force => 1,
        trace => 1,
        );#@36
    if( $flags{$name} ) {
        return "--$name=\"1\"";#@38
    }
    return "--$name";#@40
}
sub op_space {
    my ( $name, $val ) = @_;#@44
    return "--$name=\"$val\"";#@45
}

1;
