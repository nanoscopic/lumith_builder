# Copyright (C) 2018 David Helkowski

<header/>

<construct>
    <conf>
        <logfile>/var/www/html/lumith/log/log.xml</logfile>
    </conf>
</construct>

use Time::HiRes qw/time/;

sub init {
    <param name="conf" />
    if( ref( $conf ) eq 'ARRAY' ) { $conf = pop @$conf; }
    $self->{'logfile'} = $conf->{'logfile'};
}

sub tag_log {
    <tag name="log" />
    <param name="metacode" var="tag" />
    
    my $type = $tag->{'type'} or die "log msg does not specify a type";
    my @parts;
    for my $key ( keys %$tag ) {
        next if( $key eq 'type' );
        my $val = $tag->{ $key };
        if( $val =~ m/^`/ ) {
            $val = substr( $val, 1 );
            push( @parts, "$key => ($val)" );
        }
        elsif( $val =~ m/\$/ ) {
            push( @parts, "$key => ($val)" );
        }
        else {
            push( @parts, "$key => \"$val\"" );
        }
    }
    my $partT = join( ",\n", @parts );
    return "\$mod_log->log_msg( '$type', _line => __LINE__, _file => __FILE__, $partT );\n";
}

sub log_msg( type ) {
    <param name="_line" />
    <param name="_file" />
    undef $_params{'_line'};
    undef $_params{'_file'};
    my $logfile = $self->{'logfile'};
    open( LOG, ">>$logfile" ) or die "Could not open $logfile";
    my %xparams;
    for my $key ( keys %_params ) {
        $xparams{$key} = { value => $_params{$key} };
    }
    my $xml = XML::Bare::Object::xml( 0, {
        e => {
            type => { value => $type,  _att => 1 },
            time => { value => time(), _att => 1 },
            line => { value => $_line,  _att => 1 },
            file => { value => $_file,  _att => 1 },
            %xparams
        }
    } );
    print LOG $xml;
    close( LOG );
}