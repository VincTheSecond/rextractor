#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

use RExtractor::Relations::DBR;

package RExtractor::Presentation::INTLIB;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

# Load document
sub load {
    my ($self, $filename) = @_;

    ## Obtain document ID

    my $id = $filename;
    $id =~ s/^(?:.*\/)?([^\/]+)$/$1/;
    $self->{id} = $id;

    ## Load exported document as XML
    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename);
    };
    if ($@) {
        $self->{error} = $@;
        return 0;
    }

    
    ## Load exported document as plain-text
    $self->{lines} = [];
    $self->{chunks} = {};
    if (!open(FILE, "<$filename")) {
        return 0;
    }
    binmode(FILE, ":encoding(utf8)");
    while (<FILE>) {
        chomp($_);
        push(@{$self->{lines}}, $_);

        my $line = $_;
        while ($line =~ s/<annotation id="(\d+)">(.*?)<\/annotation>//) {
            $self->{chunks}{$1} = $2;
        }
    }
    close(FILE);

    ## Load description file
    $filename =~ s/.html$/.xml/;
    eval {
        $self->{description} = XML::LibXML->load_xml(location => $filename);
    };
    if ($@) {
        $self->{error} = $@;
        return 0;
    }

    ## Mapping which chunks is in which text-element
    $self->{chunk2pos} = {};
    my @p = $self->{xml}->findnodes("//p");
    for (my $i = 0; $i < scalar(@p); $i++) {
        my @annotations = $p[$i]->findnodes("./annotation");
        foreach my $annotation (@annotations) {
            my $id = $annotation->getAttribute("id");
            $self->{chunk2pos}{$id}{$i} = defined;
        }
    }
    $self->{xml_p} = \@p;

    ## Create mapping chunk_id2entity_id
    $self->{chunk2entity} = {};
    $self->{entity2text} = {};
    $self->{entity2chunk} = {};
    $self->{chunk2dbe} = {};
    my @entities = $self->{description}->findnodes("//entity");
    foreach my $entity (@entities) {
        my $entity_id = $entity->getAttribute('entity_id');
        my $dbe_id = $entity->getAttribute('dbe_id');
        my @chunks = ();
        foreach my $chunk (split(/\s+/, $entity->getAttribute('chunk_ids'))) {
            if (defined($dbe_id)) {
                $self->{chunk2dbe}{$chunk}{$dbe_id} = defined;
            }
            $self->{chunk2entity}{$chunk}{$entity_id} = defined;
            $self->{entity2chunk}{$entity_id}{$chunk} = defined;
            push(@chunks, $self->{chunks}{$chunk}) if (defined($self->{chunks}{$chunk}));
        }
        $self->{entity2text}{$entity_id} = join(" ", @chunks);
    }

    return 1;
}

sub getRelations {
    my ($self, $DBR) = @_;
    my $output = "";

    my @relations = $self->{description}->findnodes("//relation");
    foreach my $relation (@relations) {
        my $dbr_id = $relation->getAttribute("dbr_id");

        my $subject_concept = $relation->getAttribute("subject_concept");
        my @subject_ids = split(/\s+/, $relation->getAttribute("subject_ids"));
        if (!scalar(@subject_ids)) {
            push(@subject_ids, "");
        }

        my $predicate_concept = $relation->getAttribute("predicate_concept");
        my @predicate_ids = split(/\s+/, $relation->getAttribute("predicate_ids"));
        if (!scalar(@predicate_ids)) {
            push(@predicate_ids, "");
        }

        my $object_concept = $relation->getAttribute("object_concept");
        my @object_ids = split(/\s+/, $relation->getAttribute("object_ids"));
        if (!scalar(@object_ids)) {
            push(@object_ids, "");
        }

        foreach my $subject_id (@subject_ids) {
            foreach my $predicate_id (@predicate_ids) {
                foreach my $object_id (@object_ids) {
                    # Make list of text elements where chunks from relation appear
                    my %text_elements = ();
                    my %chunk_to_highlight = ();
                    for my $chunk_id (keys %{$self->{entity2chunk}{$subject_id}}) {
                        foreach my $text_pos (keys %{$self->{chunk2pos}{$chunk_id}}) {
                            $text_elements{$text_pos} = 1;
                            $chunk_to_highlight{subject}{$chunk_id} = defined;
                        }
                    }
                    for my $chunk_id (keys %{$self->{entity2chunk}{$predicate_id}}) {
                        foreach my $text_pos (keys %{$self->{chunk2pos}{$chunk_id}}) {
                            $text_elements{$text_pos} = 1;
                            $chunk_to_highlight{predicate}{$chunk_id} = defined;
                        }
                    }
                    for my $chunk_id (keys %{$self->{entity2chunk}{$object_id}}) {
                        foreach my $text_pos (keys %{$self->{chunk2pos}{$chunk_id}}) {
                            $text_elements{$text_pos} = 1;
                            $chunk_to_highlight{object}{$chunk_id} = defined;
                        }
                    }

                    my @text = ();
                    foreach my $text_id (sort keys %text_elements) {
                        my $line .= $self->{xml_p}[$text_id]->toString();
                        foreach my $type ("subject", "predicate", "object") {
                            foreach my $chunk_id (keys %{$chunk_to_highlight{$type}}) {
                                $line =~ s/<annotation id="$chunk_id">(.*?)<\/annotation>/<span class='chunk_$type' id='$chunk_id'>$1<\/span>/;
                            }
                        }
                        push(@text, $line);
                    }

                    # Print data
                    $output .= "Relation #$dbr_id - $DBR->{queries}{$dbr_id}{description}\n";
                    $output .= join("\t", (
                        defined($subject_id) ? $subject_id : "",
                        defined($self->{entity2text}{$subject_id}) ? $self->{entity2text}{$subject_id} : "",
                        defined($predicate_id) ? $predicate_id : "",
                        defined($self->{entity2text}{$predicate_id}) ? $self->{entity2text}{$predicate_id} : "",
                        defined($object_id) ? $object_id : "",
                        defined($self->{entity2text}{$object_id}) ? $self->{entity2text}{$object_id} : ""
                    ));
                    $output .= "\n";
                    $output .= join("<br>", @text);
                    $output .= "\n";
                }
            }
        }
    }

    return $output;
}

# HTML presentation...
sub getHTML {
    my ($self) = @_;

    my $output = "";
    foreach my $line (@{$self->{lines}}) {
        foreach my $chunk (keys %{$self->{chunk2dbe}}) {
            $line =~ s/<annotation id="$chunk">(.*?)<\/annotation>/<span class='chunk' id='$chunk'>$1<\/span>/g;
        }

        if ($line =~ /(<p>.*<\/p>)/) {
            $output .= $1;
        }
    }

    return $output;
}

1;
