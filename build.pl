#!/usr/bin/perl -w
# Copyright (C) 2018 David Helkowski

use strict;
use warnings;

use lib 'built';
use lib 'prebuilt';
use Melon::Builder::systemx;
use Melon::Builder::cmdline;
my $sys = Melon::Builder::systemx->new();
my $builder = $sys->getmod("builder");
$builder->init2( file => 'conf/[some conf you want to build].xml' );
$builder->build( %{Melon::Builder::cmdline::parse_args( \@ARGV )} );