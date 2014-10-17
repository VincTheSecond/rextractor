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

    ## Load exported document

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

    ## Create mapping chunk_id2entity_id
    $self->{chunk2entity} = {};
    $self->{entity2text} = {};

    my @entities = $self->{description}->findnodes("//entity");
    foreach my $entity (@entities) {
        my $entity_id = $entity->getAttribute('entity_id');
        my @chunks = ();
        foreach my $chunk (split(/\s+/, $entity->getAttribute('chunk_ids'))) {
            $self->{chunk2entity}{$chunk}{$entity_id} = defined;
            push(@chunks, $self->{chunks}{$chunk}) if (defined($self->{chunks}{$chunk}));
        }
        $self->{entity2text}{$entity_id} = join(" ", @chunks);
    }

    return 1;
}

# Return data about relations
sub getRelations {
    my ($self, $DBR) = @_;

    my $previous_dbr_id = 0;
    my @relations = $self->{description}->findnodes("//relation");
    foreach my $relation (@relations) {
        my $dbr_id = $relation->getAttribute("dbr_id");

        if ($dbr_id != $previous_dbr_id) {
            print "<h4>Relation #$dbr_id</h4>\n";
            print "<i>$DBR->{queries}{$dbr_id}{description}</i>\n";
            $previous_dbr_id = $dbr_id;
        }

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
                    print join("\t", (
                       defined($dbr_id) ? $dbr_id : "",
                        defined($subject_id) ? $subject_id : "",
                        defined($subject_concept) ? $subject_concept : "",
                        defined($self->{entity2text}{$subject_id}) ? $self->{entity2text}{$subject_id} : "",
                        defined($predicate_id) ? $predicate_id : "",
                        defined($predicate_concept) ? $predicate_concept : "",
                        defined($self->{entity2text}{$predicate_id}) ? $self->{entity2text}{$predicate_id} : "",
                        defined($object_id) ? $object_id : "",
                        defined($object_concept) ? $object_concept : "",
                        defined($self->{entity2text}{$object_id}) ? $self->{entity2text}{$object_id} : ""
                    ));
                    print "\n";
                }
            }
        }
    }
}

# HTML presentation...
sub getHTML {
    my ($self) = @_;

    my $output = "";
    foreach my $line (@{$self->{lines}}) {
        $line =~ s/<annotation id="([^"]+)">/<span class='chunk' id='$1'>/g;
        $line =~ s/<\/annotation>/<\/span>/g;

        if ($line =~ /(<p>.*<\/p>)/) {
            $output .= $1;
        }
    }

    return $output;
}

1;
