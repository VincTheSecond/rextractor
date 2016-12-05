#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::NLP;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document) = @_;
    print STDERR "RExtractor::NLP::process(@_)\n";

    return "";
}

1;