#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Relations;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document, $Serialized, $DBR) = @_;
    print STDERR "RExtractor::Relations::process(@_)\n";

    return "";
}

1;