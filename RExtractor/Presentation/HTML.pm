#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;

package RExtractor::Presentation::HTML;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub getHead {
    my ($self, $title) = @_;

    my $output = "";
    $output .= "<!DOCTYPE html>\n";
    $output .= "<html lang='cs'>\n";
    $output .= "<head>\n";
    $output .= "\t<meta http-equiv='content-type' content='text/html; charset=utf-8'/>\n";
    $output .= "\t<title>$title</title>\n";
    $output .= "\t<link rel='stylesheet' type='text/css' href='styles.css'/>\n";
    $output .= "\t<script type='text/javascript' src='jquery-1.7.1.min.js'></script>\n";
    $output .= "\t<script type='text/javascript' src='scripts.js'></script>\n";
    $output .= "</head>\n";

    return $output;
}

sub getQueryDetails {
    my ($self, $XMLQueryData) = @_;

    ## Extract data from XML
    my $query_id = $XMLQueryData->getAttribute("id");
    my $description = $XMLQueryData->findnodes("./description")->to_literal();
    my $pml_tq = $XMLQueryData->findnodes("./pml_tq")->to_literal();
    my @annotations = ();
    foreach my $annotate ($XMLQueryData->findnodes("./annotations/annotate")) {
        push (@annotations, {
            type => $annotate->getAttribute("type"),
            position => $annotate->getAttribute("position")});
    }
    my @results = ();
    foreach my $column ($XMLQueryData->findnodes("./result/column")) {
        push (@results, {
            type => $column->getAttribute("type"),
            chunk_id => $column->getAttribute("chunk_id"),
            concept => $column->getAttribute("concept")});
    }

    my $output = "";
    $output .= "<div class='query_details'>";
    
    $output .= "<div class='query_details_id'>$query_id</div>";
    $output .= "<div class='query_details_description'>$description</div>";
    $output .= "<div style='clear: both'></div>";
    $output .= "<div class='query_details_pml'>$pml_tq</div>";
    
    $output .= "<div class='query_details_annotations'>";
    foreach my $annotation (@annotations) {
        $output .= "<div class='query_details_annotations_item'>";
        $output .= "<div class='query_details_annotations_item_type'>$annotation->{type}</div>";
        $output .= "<div class='query_details_annotations_item_position'>$annotation->{position}</div>";
        $output .= "<div style='clear: both'></div>";
        $output .= "</div>";
    }
    $output .= "</div>";

    $output .= "<div class='query_details_results'>";
    foreach my $result (@results) {
        $result->{type} = "" if (!$result->{type});
        $result->{chunk_id} = "" if (!$result->{chunk_id});
        $result->{concept} = "" if (!$result->{concept});

        $output .= "<div class='query_details_results_item'>";
        $output .= "<div class='query_details_results_item_type'>$result->{type}</div>";
        $output .= "<div class='query_details_results_item_chunk_id'>$result->{chunk_id}</div>";
        $output .= "<div class='query_details_results_item_concept'>$result->{concept}</div>";
        $output .= "<div style='clear: both'></div>";
        $output .= "</div>";
    }
    $output .= "</div>";

    $output .= "</div>";
}

sub getColumn {
    my ($self, $DB_Entities, $Description, $relation, $column) = @_;
    #print STDERR "getColumn($Description, $relation, $column)\n";

    my $item_text = "";
    my $item_chunk = "";
    my $item_concept = "";

    my @items = $relation->findnodes("./$column");
    if (scalar(@items) == 0) {
        return ("", "", "");
    }
    my $item = $items[0];

    $item_chunk = $item->getAttribute("chunk_id") ? $item->getAttribute("chunk_id") : "";
    $item_concept = $item->getAttribute("concept");

    ## Najdeme chunk
    if ($item_chunk) {
        my $xpath = "//chunk[starts-with(\@id, '$item_chunk.') or \@id='$item_chunk']";
        my @chunks = $Description->{xml}->findnodes($xpath);
        my $chunk = $chunks[0];

        my @types = $chunk->findnodes('./type');
        my $type = $types[0]->toString();

        #print STDERR "Type = $type\n";
        #print STDERR "Chunk = $chunk\n";
        
        if ($type =~ /Entity/) {
            my @entity_ids = $chunk->findnodes('./entity_id');
            my $entity_id = $entity_ids[0]->to_literal();

            #print STDERR "entity_id = $entity_id\n";
            #print STDERR "query = " . '//entity[@id="$entity_id"]' . "\n";

            my @texts = $DB_Entities->findnodes("//entity[\@id=\"$entity_id\"]/original_form");
            $item_text = $texts[0]->toString();
        }
        else {
            my @texts = $chunk->findnodes('./original_form');
            $item_text = $texts[0]->toString();
        }
    }

    return ($item_text, $item_chunk, $item_concept);
}

sub getSourceText {
    my ($self, $Data, $subject_chunk, $predicate_chunk, $object_chunk) = @_;

    ## Teraz zobrazim textovy element z ktoreho som to ziskal
    my $text_sb = "";
    my $text_pred = "";
    my $text_obj = "";

    my $id_sb = "";
    my $id_pred = "";
    my $id_obj = "";

    if ($subject_chunk) {
        my @annotations = $Data->findnodes("//annotation[starts-with(\@id, '$subject_chunk.') or \@id='$subject_chunk']");
        my $annotation = $annotations[0];

        while ($annotation->nodeName() ne "text") {
            $annotation = $annotation->parentNode();
        }

        $id_sb = $annotation->parentNode()->getAttribute("id");

        if ($annotation->to_literal() =~ /^(?:[a-z]|á|ä|č|ď|é|ě|í|ĺ|ľ|ň|ó|ô|ŕ|ř|š|ť|ů|ú|ý|ž)/) {
            my @nodes = $annotation->parentNode()->parentNode()->findnodes("./text");
            $text_sb  = $nodes[0]->toString() if (scalar(@nodes));
            $text_sb .= " ";
        }

        $text_sb .= $annotation->toString();
    }

    if ($predicate_chunk) {
        my @annotations = $Data->findnodes("//annotation[starts-with(\@id, '$predicate_chunk.') or \@id='$predicate_chunk']");
        my $annotation = $annotations[0];

        while ($annotation->nodeName() ne "text") {
            $annotation = $annotation->parentNode();
        }

        $id_pred = $annotation->parentNode()->getAttribute("id");

        if ($annotation->to_literal() =~ /^(?:[a-z]|á|ä|č|ď|é|ě|í|ĺ|ľ|ň|ó|ô|ŕ|ř|š|ť|ů|ú|ý|ž)/) {
            my @nodes = $annotation->parentNode()->parentNode()->findnodes("./text");
            $text_pred  = $nodes[0]->toString() if (scalar(@nodes));
            $text_pred .= " ";
        }

        $text_pred .= $annotation->toString();
    }

    if ($object_chunk) {
        my @annotations = $Data->findnodes("//annotation[starts-with(\@id, '$object_chunk.') or \@id='$object_chunk']");
        my $annotation = $annotations[0];

        while ($annotation->nodeName() ne "text") {
            $annotation = $annotation->parentNode();
        }

        $id_obj = $annotation->parentNode()->getAttribute("id");

        if ($annotation->to_literal() =~ /^(?:[a-z]|á|ä|č|ď|é|ě|í|ĺ|ľ|ň|ó|ô|ŕ|ř|š|ť|ů|ú|ý|ž)/) {
            my @nodes = $annotation->parentNode()->parentNode()->findnodes("./text");
            $text_obj  = $nodes[0]->toString() if (scalar(@nodes));
            $text_obj .= " ";
        }

        $text_obj .= $annotation->toString();
    }

    my $text = $text_sb;
    if ($text_pred and ($text_sb ne $text_pred)) {
        if ($text_pred =~ /^[A-Z]/) {
            $text = $text_pred . $text;
        }
        else {
            $text .= $text_pred;
        }
    }
    if ($text_obj and ($text_sb ne $text_obj) and ($text_pred ne $text_obj)) {
        $text .= $text_obj;
    }

    #print "\nTEXT = $text\n";
    $text =~ s/<\/?text>//g;
    $text =~ s/<annotation id="$subject_chunk(?:\.\d+)?">(.*?)<\/annotation>/<span style='background: #ffaaff'>$1<\/span>/g;# if ($subject_chunk);
    $text =~ s/<annotation id="$predicate_chunk(?:\.\d+)?">(.*?)<\/annotation>/<span style='background: #aaffff'>$1<\/span>/g;# if ($predicate_chunk);
    $text =~ s/<annotation id="$object_chunk(?:\.\d+)?">(.*?)<\/annotation>/<span style='background: #ffffaa'>$1<\/span>/g;# if ($object_chunk);
    $text =~ s/<annotation[^>]+>//g;
    $text =~ s/<\/annotation>//g;

    if ($id_sb and
        $id_pred and 
        $id_sb != $id_pred) {
        print STDERR "Different trees (sb vs. pred): $id_sb vs. $id_pred\n";
    }
    if ($id_sb and
        $id_obj and
        $id_sb != $id_obj) {
        print STDERR "Different trees (sb vs. obj): $id_sb vs. $id_obj\n";
    }
    if ($id_pred and
        $id_obj and
        $id_pred != $id_obj) {
        print STDERR "Different trees (pred vs. obj): $id_pred vs. $id_obj\n";
    }

    return ($text, sprintf("%03d", $id_sb));
}

1;