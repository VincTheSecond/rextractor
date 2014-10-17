#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

package RExtractor::Conversion::INTLIB;

my @ISA = qw(RExtractor::Conversion);

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub loadFile {
    my ($self, $filename) = @_;

    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename);
    };

    if ($@) {
        return 0;
        $self->{error} = $@;
    }

    return 1;
}

sub convert {
    my ($self, $ra_lines) = @_;

    ## Extracting <p> elements from source XML
    my @p = $self->{xml}->findnodes("//p");
    my @text = ();
    foreach my $p (@p) {
        push(@text, $p->to_literal());
    }

    ## Join 2 segments if there is one sentence split into 2 segments
    my @joined_text = ();
    for (my $i = 0; $i < scalar(@text); $i++) {
        my @segments = ({text => $text[$i], id => $i});

        my $was_joined = 0;
        my $j = 0;
        for ($j = $i + 1; $j < scalar(@text); $j++) {
            if (_hasLabels($text[$j]) or
                $text[$j] =~ /^\p{Lu}/) {
                last;
            }

            push(@segments, {text => $text[$j], id => $j});
        }

        my $joined_text = "";
        my @resources_info = ();
        foreach my $segment (@segments) {
            my $unlabeled_segment = _removeLabels($segment->{text});
            $joined_text .= " " if ($joined_text);

            push(@resources_info, {
                id => $segment->{id},
                start => length($joined_text),
                end => length($joined_text) + length($unlabeled_segment)
            });

            $joined_text .= $unlabeled_segment;
        }
        push(@joined_text, {
            text => $joined_text,
            resources => \@resources_info
        });

        if ($j > $i + 1) {
            $i = $j - 1;
        }
    }

    ## Distribude segment if there is one sentence split into 2 segments
    @text = @joined_text;
    @joined_text = ();
    for (my $i = 0; $i < scalar(@text); $i++) {
        my $j = 0;
        for ($j = $i + 1; $j < scalar(@text); $j++) {
            if ($text[$j]->{text} =~ /^\p{Lu}/) {
                last;
            }

            my @resources_info = @{$text[$i]->{resources}};
            foreach my $resource_info (@{$text[$j]->{resources}}) {
                $resource_info->{start} += length($text[$i]->{text}) + 1;
                $resource_info->{end} += length($text[$i]->{text}) + 1;
                push(@resources_info, $resource_info);
            }

            push(@joined_text, {
                text => "$text[$i]->{text} $text[$j]->{text}",
                resources => \@resources_info
            });
        }

        if ($j > $i + 1) {
            $i = $j - 1;
            next;
        }

        push(@joined_text, $text[$i]);
    }

    $self->{text} = \@joined_text;
    return \@joined_text;
}

sub saveFile {
    my ($self, $filename) = @_;

    # Create new XML doc
    my $Document = XML::LibXML::Document->new("1.0", "utf-8");
    my $root = $Document->createElement("document");
    $Document->setDocumentElement($root);

    # Empty metadata
    my $metadata = $Document->createElement("metadata");
    $root->appendChild($metadata);

    # Body
    my $body = $Document->createElement("body");
    my $description = $Document->createElement("description");
    my $resources = $Document->createElement("resources");

    for (my $i = 0; $i < scalar(@{$self->{text}}); $i++) {
        # Create text element
        my $text = $Document->createElement("text");
        $text->setAttribute("id", $i + 1);
        $text->appendText($self->{text}[$i]->{text});
        $body->appendChild($text);

        # Create resources elements
        foreach my $resource_info (@{$self->{text}[$i]->{resources}}) {
            my $resource = $Document->createElement("resource");
            $resource->setAttribute("text_id", $i + 1);
            $resource->setAttribute("resource", $resource_info->{id});
            $resource->setAttribute("start", $resource_info->{start});
            $resource->setAttribute("end", $resource_info->{end});

            $resources->appendChild($resource);
        }
    }

    $root->appendChild($body);
    $description->appendChild($resources);
    $root->appendChild($description);

    open(my $OUTPUT, ">$filename");
    $Document->toFH($OUTPUT, 2);
    close($OUTPUT);

    return 1;
}

# From given text removes formal labels like (1), a), ...
sub _removeLabels {
    my ($text) = @_;

    $text =~ s/^\s*\(\s*\d+\s*\)\s*//;
    $text =~ s/^\s*[a-z]+\s*\)\s*//;

    return $text;
}

# Returns 1 if text starts with formal labels, like (1), a), ...
sub _hasLabels {
    my ($text) = @_;

    return 1 if ($text =~ s/^\s*\(\s*\d+\s*\)\s*//);
    return 1 if ($text =~ s/^\s*[a-z]+\s*\)\s*//);

    return 0;
}

1;
