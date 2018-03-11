package Builder::Core::log;
use Time::HiRes ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Builder::Core::log::init ) && !$self->{'skipInit'} );
                return $self;
            }use Time::HiRes qw/time/;#@9
sub init { #@11
    my $self=shift;
  my %_params = @_;
    my $conf = $_params{'conf'};#@12
    if( ref( $conf ) eq 'ARRAY' ) { $conf = pop @$conf; }
    $self->{'logfile'} = $conf->{'logfile'};#@14
}
sub tag_log { #@17
    my $self=shift;
  my %_params = @_;
    my $mod_log = $self->{'mod_log'};
    my $tag = $_params{'metacode'};#@19
    my $type = $tag->{'type'} or die "log msg does not specify a type";#@21
    my @parts;#@22
    for my $key ( keys %$tag ) {
        next if( $key eq 'type' );#@24
        my $val = $tag->{ $key };#@25
        if( $val =~ m/^`/ ) {
            $val = substr( $val, 1 );#@27
            push( @parts, "$key => ($val)" );#@28
        }
        elsif( $val =~ m/\$/ ) {
            push( @parts, "$key => ($val)" );#@31
        }
        else {
            push( @parts, "$key => \"$val\"" );#@34
        }
    }
    my $partT = join( ",\n", @parts );#@37
    return "\$mod_log->log_msg( '$type', _line => __LINE__, _file => __FILE__, $partT );\n";#@38
}
sub log_msg { #@41
    my $self=shift;
    my $type = shift;
  my %_params = @_;
    my $_line = $_params{'_line'};#@42
    my $_file = $_params{'_file'};#@43
    undef $_params{'_line'};#@44
    undef $_params{'_file'};#@45
    my $logfile = $self->{'logfile'};#@46
    open( LOG, ">>$logfile" ) or die "Could not open $logfile";#@47
    my %xparams;#@48
    for my $key ( keys %_params ) {
        $xparams{$key} = { value => $_params{$key} };#@50
    }
    my $xml = XML::Bare::Object::xml( 0, {
        e => {
            type => { value => $type,  _att => 1 },
            time => { value => time(), _att => 1 },
            line => { value => $_line,  _att => 1 },
            file => { value => $_file,  _att => 1 },
            %xparams
        }
    } );#@60
    print LOG $xml;#@61
    close( LOG );#@62
}
sub setup_tags { #@?
    my $self=shift;
    my $tagsystem = shift;
  my %_params = @_;
    my $lang = $_params{'lang'};#@?
                print 'Setting up tags from module '.__FILE__."\n";#@?
                $self->{'lang'} = $lang || 'perl';#@?
            $tagsystem->register_tag(
                name => 'log',
                func => \&tag_log,
                mod => $self,
                stage => 'normal',
                type => 'normal'
            );#@?
}

1;
