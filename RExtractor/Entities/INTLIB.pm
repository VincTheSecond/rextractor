#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

use RExtractor::Entities::Annotation;

package RExtractor::Entities::INTLIB;

my @ISA = qw(RExtractor::Entities);

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document, $Serialized) = @_;

    $self->{strategy} = $Strategy;
    $self->{document} = $Document;
    $self->{serialized} = $Serialized;

    $self->{output_file} = "./servers/tmp/entity/$self->{document}{id}.csv";

    print STDERR "Run detection\n"; # FIXME
    return 0 if (!$self->_runDetection());

    print STDERR "Annotate\n"; # FIXME
    return 0 if (!$self->_annotate());

    return 1;
}

sub _runDetection {
    my ($self) = @_;

    my $filename = "./data/treex/$self->{document}{id}.treex.gz";

    my $command = $self->{strategy}{entities}{detection};
    $command =~ s/#DOCUMENT_FILENAME#/$filename/;
    $command =~ s/#OUTPUT_FILE#/$self->{output_file}/;

    my $return_value = system($command);
    print STDERR "Entity detection command returned value $return_value\n"; # FIXME
    return 0 if ($return_value);
    return 1;
}

sub _annotate {
    my ($self) = @_;

    my $Annotate = new RExtractor::Entities::Annotation();

    return 0 if (!$Annotate->load($self->{output_file}));
    return 0 if (!$Annotate->annotate($self->{document}, $self->{serialized}));
    return 1;
}
1;
