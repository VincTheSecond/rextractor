#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Entities;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document, $Serialized) = @_;
    print STDERR "RExtractor::Entities::process(@_)\n";

    return "";
}

1;