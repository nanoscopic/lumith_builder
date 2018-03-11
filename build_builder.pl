#!/usr/bin/perl -w
# Copyright (C) 2018 David Helkowski

use strict;
use warnings;

use lib 'built';
use lib 'prebuilt';
use Melon::Builder::systemx;
use Melon::Builder::cmdline;

my $args = Melon::Builder::cmdline::parse_args( \@ARGV );

print "***********************Building Core**\n";
my $sys = Melon::Builder::systemx->new();
my $builder = $sys->getmod("builder");
$builder->init2( file => 'conf/core.xml', name => "BCore", namespace => "Builder/Core", dir => 'built_builder' );
$builder->build(%$args);

print "\n***********************Building Core2**\n";
$sys = Melon::Builder::systemx->new();
$builder = $sys->getmod("builder");
$builder->init2( file => 'conf/bcore2.xml', name => "BCore2", namespace => "Builder/Core2", dir => 'built_builder' );
$builder->build(%$args);

print "\n***********************Building Builder**\n";
$sys = Melon::Builder::systemx->new();
$builder = $sys->getmod("builder");
$builder->init2( file => 'conf/builder.xml', dir => 'built_builder' );
$builder->build(%$args);