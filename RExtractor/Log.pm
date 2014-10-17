#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Log;

sub new {
    my ($self) = @_;

    $self = {};
    $self->{file_handler} = undef;
    $self->{level}
    bless $self;
    return $self;
}

sub setLevel {
    my ($self, $level) = @_;

    $self->{}
}

sub open {
    my ($self, $filename) = @_;

    open($self->{file_handler}, "<$filename");
    return 1;
}

sub writeFile {
    my ($filename, $data) = @_;

    if (-f $filename) {
        return 0;
    }

    open(FILE, ">$filename");
    print FILE $data;
    close(FILE);

    return 1;
}

1;