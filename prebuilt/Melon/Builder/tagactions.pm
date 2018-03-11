package Melon::Builder::tagactions;
use Data::Dumper ;
use File::Slurp ;
use strict;
use warnings;#@1
my $SYS;

            sub new {
                my $class = shift;
                my %params = @_;
                my $self = bless {}, $class;
                $SYS = $params{'sys'};

                    $self->{'mod_builder'} = $params{'mod_builder'} || 0;

                $self->{'_conf'} = $params{'conf'} || 0;
                $self->init(%params) if( defined( &Melon::Builder::tagactions::init ) && !$self->{'skipInit'} );
                return $self;
            }sub init { #@5
    my $self=shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $b = $mod_builder;#@6
    $b->register_action( "add_mod"          , \&action_add_mod      , $self );#@7
    $b->register_action( "add_var"          , \&action_add_var      , $self );#@8
    $b->register_action( "add_sub_var"      , \&action_add_sub_var  , $self );#@9
    $b->register_action( "add_sub_text"     , \&action_add_sub_text , $self );#@10
    $b->register_action( "add_text"         , \&action_add_text     , $self );#@11
    $b->register_action( "add_sub"          , \&action_add_sub      , $self );#@12
    $b->register_action( "create_module"    , \&action_create_module, $self );#@13
}
sub action_add_mod { #@16
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $construct = $taghash->{'construct'} ||= {};#@17
    my $modules = $construct->{'modules'} ||= {};#@18
    my $new_module = $actionNode->{'mod'};#@19
    $modules->{ $new_module } = {
        delayed => ( $actionNode->{'delayed'} || 0 ),
        var => ( $actionNode->{'var'} || '' )
    };#@23
    0;#@24
}
sub action_add_var { #@27
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $vars = $cursub->{'vars'};#@28
    my $as = $actionNode->{'var'} || '';#@29
    push( @$vars, { self => $actionNode->{'self'}, var => $as } );#@30
    0;#@31
}
sub action_add_sub_var { #@34
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $subNameToAddTo = $actionNode->{'sub'};#@35
    my $subToAddTo = $subhash->{$subNameToAddTo};#@36
    my $vars = $subToAddTo->{'vars'};#@37
    my $as = $actionNode->{'var'} || '';#@38
    push( @$vars, { self => $actionNode->{'self'}, var => $as } );#@39
    0;#@40
}
sub action_add_sub_text { #@43
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $module = $_params{'module'};#@44
    my $modinfo = $_params{'modinfo'};#@45
    my $subNameToAddTo = $actionNode->{'sub'};#@46
    my @lines = split(/\n/, $actionNode->{'text'});#@47
    my $newParts = $mod_builder->split_lines_to_parts( \@lines );#@48
    $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );#@49
    my $subToAddTo = $subhash->{$subNameToAddTo};#@51
    my $subparts = $subToAddTo->{'parts'};#@52
    cut_ending_paran( $subparts );#@53
    push( @$subparts, @$newParts, { type => 'line', text => "}\n" } );#@54
    0;#@55
}
sub action_add_text { #@58
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $module = $_params{'module'};#@59
    my $modinfo = $_params{'modinfo'};#@60
    my @lines = split(/\n/, $actionNode->{'text'});#@61
    my $newParts = $mod_builder->split_lines_to_parts( \@lines );#@62
    $mod_builder->parse_xml_parts( $newParts );#@63
    $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );#@64
    my $moreXml = $mod_builder->parse_xml_parts( $newParts );#@66
    if( $moreXml ) {
        $newParts = $mod_builder->process_xml_parts( $module, $modinfo, $newParts );#@68
    }
    return $newParts;#@71
}
sub action_add_sub { #@74
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $subToAdd = $actionNode->{'name'};#@75
    if( !$subhash->{ $subToAdd } ) {
        my $text = $actionNode->{'text'};#@78
        if( !$text ) {
            $text = "sub $subToAdd {\n}\n";#@80
        }
        my @lines = split(/\n/, $text);#@82
        my $newParts = $mod_builder->split_lines_to_parts( \@lines );#@83
        $mod_builder->parse_xml_parts( $newParts );#@84
        my $newSubs = $mod_builder->split_parts_to_subs( $newParts );#@85
        my $subs = $mod_builder->{'subs'};#@86
        shift @$newSubs; # delete the 'init' sub
        push( @$subs, @$newSubs );#@88
    }
    else {
    }
    0;#@93
}
sub action_create_module { #@96
    my $self=shift;
    my $actionNode = shift;
    my $taghash = shift;
    my $cursub = shift;
    my $subhash = shift;
  my %_params = @_;
    my $mod_builder = $self->{'mod_builder'};
    my $module_build_result = $mod_builder->{'module_build_result'};#@97
    my $new_modules = $module_build_result->{'new_modules'} ||= [];#@98
    my $newFile = $actionNode->{'file'};#@100
    my @parts = split( "/", $newFile );#@102
    my $fileName = pop( @parts );#@103
    my $path = ".";#@104
    for my $part ( @parts ) {
        $path .= "/$part";#@106
        if( ! -e $path ) {
            mkdir $path;#@108
        }
    }
    my $text = $actionNode->{'text'};#@112
    write_file( $newFile, $text );#@113
    my $newConf = {
        name => $actionNode->{'name'},
        file => $newFile,
        generated => 1
    };#@119
    if( $actionNode->{'multiple'} ) {
        $newConf->{'multiple'} = 1;#@121
    }
    push( @$new_modules, $newConf );#@123
    0;#@124
}
sub cut_ending_paran {
    my $parts = shift;#@128
    my $i = 0;#@129
    my $ok = 0;#@130
    return if( !$parts );#@131
    for( $i=((scalar @$parts)-1); $i >= 0; $i-- ) {
        my $part = $parts->[ $i ];#@133
        my $type = $part->{'type'};#@134
        if( $type eq 'line' ) {
            my $text = $part->{'text'};#@136
            if( $text =~ m/^\s*\}\s*$/ ) {
                $ok = 1;#@138
                last;#@139
            }
        }
    }
    die if( !$ok );#@143
    delete $parts->[ $i ];#@144
}

1;
