#!/usr/bin/perl

use strict;
use warnings;

use RExtractor::Relations::Annotation;

package RExtractor::Relations::INTLIB;

my @ISA = qw(RExtractor::Relations);

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document, $Serialized, $DBR) = @_;

    $self->{strategy} = $Strategy;
    $self->{document} = $Document;
    $self->{serialized} = $Serialized;
    $self->{dbr} = $DBR;

    $self->{output_file} = "./servers/tmp/relation/$self->{document}{id}.csv";

    print STDERR "Run detection\n"; # FIXME
    return 0 if (!$self->_runDetection());

    print STDERR "Annotate\n"; # FIXME
    return 0 if (!$self->_annotate());

    return 1;
}

sub _runDetection {
    my ($self) = @_;

    my $filename = "./data/treex/$self->{document}{id}.treex.gz";

    my $command = $self->{strategy}{relation}{detection};
    $command =~ s/#DOCUMENT_FILENAME#/$filename/;
    $command =~ s/#OUTPUT_FILE#/$self->{output_file}/;

    my $return_value = system($command);
    print STDERR "Relation detection command returned value $return_value\n"; # FIXME
    return 0 if ($return_value);
    return 1;
}

sub _annotate {
    my ($self) = @_;

    my $Annotate = new RExtractor::Relations::Annotation();

    return 0 if (!$Annotate->load($self->{output_file}));
    return 0 if (!$Annotate->annotate($self->{dbr}, $self->{document}, $self->{serialized}));
    return 1;
}

1;