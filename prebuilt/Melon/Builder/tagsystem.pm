package Melon::Builder::tagsystem;
use Data::Dumper ;
use XML::Bare qw/forcearray/;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                
                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::tagsystem::init ) && !$self->{'skipInit'} );
                return $self;
            }sub register_tag { #@5
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $tagname = $_params{'name'};#@6
    my $func = $_params{'func'};#@7
    my $mod = $_params{'mod'};#@8
    my $stageName = $_params{'stage'};#@9
    my $type = $_params{'type'};#@10
    my $aliasP = $_params{'alias'};#@11
    $type ||= 'normal';#@13
    $aliasP ||= 0; # this is probably not needed...
    if( !$stageName ) {
        die "Stage must be specified when registering a tag";#@19
    }
    my $stageHash = $mod_builder->{'stage_hash'};#@21
    my $stage = $stageHash->{ $stageName } or die "Could not find stage $stageName";#@22
    my $tags = $stage->{'tags'};#@24
    my $callback_info = { func => $func, mod => $mod };#@26
    $tags->{ $tagname } = $callback_info;#@27
    if( $aliasP ) {
        my $aliasA = forcearray( $aliasP );#@29
        for my $alias ( @$aliasA ) {
            $tags->{ $alias } = $callback_info;#@31
            if( $type eq 'raw' ) {
                $mod_builder->{'raw_tags'}{ $alias } = 1;#@34
            }
        }
    }
    if( $type eq 'raw' ) {
        $mod_builder->{'raw_tags'}{ $tagname } = 1;#@40
    }
}
sub process_tag { #@45
    my $self=shift;
    my $modXML = shift;
    my $xml = shift;
    my $modinfo = shift;
    my $ln = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $tags = $mod_builder->{'curTags'};#@46
    my $taghash = $mod_builder->{'taghash'};#@47
    my $key = Melon::Builder::builder::get_first_key( $xml );#@50
    my $tagdata = $taghash->{ $key } ||= {};#@52
    my $metacode = $xml->{ $key };#@54
    if( !ref( $metacode ) && $metacode =~ m/^\s*$/ ) { $metacode = {}; }
    my $params = {
        modXML => $modXML, # xml from build config file for the module
        metacode => $metacode, # the xml node of the tag being run
        tagdata => $tagdata,
        modInfo => $modinfo, # hash containing some basic info about the module
        builder => $mod_builder,
        ln => $ln
    };#@64
    if( $tags->{ $key } ) {
        my $info = $tags->{ $key };#@67
        my $func = $info->{'func'};#@68
        return $func->( $info->{'mod'}, %$params );#@69
    }
    return 0;#@72
}

1;
