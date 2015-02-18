#!/usr/bin/perl

use strict;
use warnings;

use utf8;

package RExtractor::Export;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self) = @_;

    return 0;
}

1;
