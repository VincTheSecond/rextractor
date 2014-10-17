#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Conversion;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub loadFile {
    my ($self, $filename) = @_;
    print STDERR "RExtractor::Conversion::loadFile(@_)\n";

    return "";
}

sub convert {
    my ($self, $ra_lines) = @_;
    print STDERR "RExtractor::Conversion::convert(@_)\n";

    return "";
}

sub saveFile {
    my ($self, $filename) = @_;
    print STDERR "RExtractor::Conversion::loadFile(@_)\n";

    return "";
}

1;
