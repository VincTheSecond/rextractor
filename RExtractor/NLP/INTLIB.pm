#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

package RExtractor::NLP::INTLIB;

my @ISA = qw(RExtractor::NLP);

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Strategy, $Document) = @_;

    $self->{strategy} = $Strategy;
    $self->{document} = $Document;

    print STDERR "Prepar dirs\n"; # FIXME
    return 0 if (!$self->_prepareTempDirs());

    print STDERR "Prepar text files\n"; # FIXME
    return 0 if (!$self->_prepareTextFiles());

    print STDERR "Run segmentation\n"; # FIXME
    return 0 if (!$self->_runSegmentation());

    print STDERR "Merge files\n"; # FIXME
    return 0 if (!$self->_mergeTreexFiles());

    print STDERR "Run morphology\n"; # FIXME
    return 0 if (!$self->_runMorphology());

    return 1;
}

sub _prepareTempDirs {
    my ($self) = @_;

    my @dirs = (
        "./servers/tmp/nlp/$self->{document}{id}",
        "./servers/tmp/nlp/$self->{document}{id}/txt",
        "./servers/tmp/nlp/$self->{document}{id}/segmented",
    );

    foreach my $dir (@dirs) {
        system("mkdir $dir");

        if (not(-d $dir)) {
            return 0;
        }
    }

    return 1;
}

sub _prepareTextFiles {
    my ($self) = @_;

    my @texts = $self->{document}{xml}->findnodes("/document/body/text");
    foreach my $textnode (@texts) {
        my $id = $textnode->getAttribute("id");
        my $text = $textnode->to_literal();

        if (!open(FILE, ">./servers/tmp/nlp/$self->{document}{id}/txt/$self->{document}{id}" . "_" . sprintf("%04d", $id) . ".txt")) {
            return 0;
        }
        binmode(FILE, ":encoding(utf-8)");
        print FILE $text;
        close(FILE);
    }

    return 1;
}

sub _runSegmentation {
    my ($self) = @_;

    my $command = $self->{strategy}{nlp}{segmentation};
    $command =~ s/#DOCUMENT_ID#/$self->{document}{id}/;

    my $return_value = system($command);
    print STDERR "Segmentation command returned value $return_value\n"; # FIXME
    if ($return_value) {
        return 0;
    }

    return 1;
}

sub _mergeTreexFiles {
    my ($self) = @_;

    my @LMs = ();
    foreach my $file (split(/\n/, `find ./servers/tmp/nlp/$self->{document}{id}/txt/ -name '*.treex' | sort`)) {
        my $subid = $file;
        $subid =~ s/^.*_(\d+)\.treex$/$1/;

        my $lm_section = 0;
        my $data = "";
        open(FILE, "<$file");
        while (<FILE>) {
            chomp($_);
            if ($_ =~ /<LM id="/) {
                $_ =~ s/id="(.*)"/id="$subid-$1"/;
                $lm_section = 1;
            }

            if ($lm_section) {
                $data .= "$_\n";
            }

            if ($_ =~ /<\/LM>/) {
                $lm_section = 0;
            }
        }
        close(FILE);

        push(@LMs, $data);
    }

    ## Merge treex files into one
    my $treex_file = "./servers/tmp/nlp/$self->{document}{id}/segmented/$self->{document}{id}.treex";
    open(OUTPUT, ">$treex_file");
    print OUTPUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<treex_document xmlns=\"http://ufal.mff.cuni.cz/pdt/pml/\">
  <head>
    <schema href=\"treex_schema.xml\" />
  </head>
  <bundles>\n";
    print OUTPUT join("\n", @LMs) . "\n";
    print OUTPUT "  </bundles>
</treex_document>
    ";
    close(OUTPUT);

    return 1;
}

sub _runMorphology {
    my ($self) = @_;

    my $treex_input_file = "./servers/tmp/nlp/$self->{document}{id}/segmented/$self->{document}{id}.treex";
    my $treex_output_file = "./data/treex/$self->{document}{id}.treex.gz";
    my $csv_output_file = "./data/serialized/$self->{document}{id}.csv";

    my $command = $self->{strategy}{nlp}{morphology};
    $command =~ s/#DOCUMENT_ID#/$self->{document}{id}/;
    $command =~ s/#TREEX_INPUT_FILE#/$treex_input_file/;
    $command =~ s/#TREEX_OUTPUT_FILE#/$treex_output_file/;
    $command =~ s/#CSV_OUTPUT_FILE#/$csv_output_file/;

    my $return_value = system($command);
    if ($return_value) {
        return 0;
    }

    return 1;
}

1;
