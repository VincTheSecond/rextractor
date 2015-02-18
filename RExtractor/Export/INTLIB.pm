#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

package RExtractor::Export::INTLIB;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub process {
    my ($self, $Document, $Serialized) = @_;

    if (!$self->load("./data/submitted/$Document->{id}.html")) {
        return 0;
    }

    if (!$self->export($Document, $Serialized)) {
        return 0;
    }

    $self->save("./data/exported/$Document->{id}.html");
    $self->saveDescription($Document, $Serialized, "./data/exported/$Document->{id}.xml");
    return 1;
}

sub load {
    my ($self, $filename) = @_;

    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename, encoding => 'utf8');
    };

    if ($@) {
        return 0;
        $self->{error} = $@;
    }

    return 1;
}

# Main export method
sub export {
    my ($self, $Document, $Serialize) = @_;

    ## XML Parser
    my $Parser = XML::LibXML->new();

    ## Data about all annotations:
    $self->{resource_chunk_id} = 0;
    $self->{annotations} = {};

    ## Error analysis - stora data about annotations where annotated
    ## text differs from text identified in Entity or Relation components
    $self->{errors} = {};

    ## Process each text in <p> separately
    my @p = $self->{xml}->findnodes("//p");
    for (my $i = 0; $i < scalar(@p); $i++) {
        my $resource_id = $i;
        my $text = $p[$i]->toString();

        print STDERR "\n\n=========================================================\n";
        print STDERR "Id:\t$resource_id\n";
        print STDERR "Text:\t$text\n";

        ## (0) Transform HTML entities to normal form
        $text =~ s/&gt;/>/g;
        $text =~ s/&lt;/</g;
        print STDERR "Text:\t$text\n";

        ## (1) Obtain text_ids which contain current source text
        print STDERR "\n** Text_ids\n";
        if (!defined($Document->{resource2text_id}{$resource_id})) {
            print STDERR "\tNo text_id for resource $resource_id\n";
            next;
        }

        my @text_ids = ();
        foreach my $text_id (sort {$a <=> $b} keys %{$Document->{resource2text_id}{$resource_id}}) {
            print STDERR "\t$text_id\t$Document->{resource2text_id}{$resource_id}{$text_id}{start}\t$Document->{resource2text_id}{$resource_id}{$text_id}{end}\n";
            push(@text_ids, $text_id);
        }

        ## (2) Obtain all chunks which are over texts in @text_ids.
        ## Filter our chunks which are not over given resource part of the text
        ## Transform positions
        print STDERR "\n*** Chunks\n";
        my %annotations = ();
        foreach my $text_id (@text_ids) {
            my @chunk_nodes = $Document->{xml}->findnodes("//chunk[\@text_id=$text_id]");
            foreach my $chunk_node (@chunk_nodes) {
                my $chunk_id = $chunk_node->getAttribute("chunk_id");
                my $chunk_start = $chunk_node->getAttribute("start");
                my $chunk_end = $chunk_node->getAttribute("end");

                print STDERR "\t$chunk_id\t$chunk_start\t$chunk_end\t";

                ## TODO
                ## Tu mam chybu!!! Ked text obsahuje viac viet, nezapocitava sa do offsetu medzera
                ## medzi vetami. Zatial to vyriesim tak, ze k offsetom pridam tolko medzier, z kolkej
                ## vety je dany chunk. Toto nezafunguje vzdy, ak bude iny pocet medzer medzi vetami.
                my $sentence_ord = $chunk_node->getAttribute("nodes");
                $sentence_ord =~ s/^.*-s(\d+)-n\d+.*$/$1/;
                $sentence_ord--;
                print STDERR "corr=$sentence_ord\t";
                $chunk_start += $sentence_ord;
                $chunk_end += $sentence_ord;

                if ($chunk_start > $Document->{resource2text_id}{$resource_id}{$text_id}{end} or
                    $chunk_end < $Document->{resource2text_id}{$resource_id}{$text_id}{start}) {
                    print STDERR "NO\n";
                    next;
                }

                # Find real chars offsets for given chunk in source text...
                my $transformation = _transformOffset($Document->{resource2text_id}{$resource_id}{$text_id}{start}, $Document->{body}{$text_id}, $text);
                $annotations{$chunk_id}{start} = $transformation->{start}[$chunk_start];
                $annotations{$chunk_id}{end} = $transformation->{end}[$chunk_end];

                print STDERR "YES\t";
                print STDERR _extractTextChunk($Document->{body}{$text_id}, $chunk_start, $chunk_end);
                print STDERR "\n";
                print STDERR "\t\t$transformation->{start}[$chunk_start]\t$transformation->{end}[$chunk_end]\t\t\t";
                print STDERR _extractTextChunk($text, $transformation->{start}[$chunk_start], $transformation->{end}[$chunk_end]);
                print STDERR "\n";

                my $from_components = _extractTextChunk($Document->{body}{$text_id}, $chunk_start, $chunk_end);
                my $in_resource = _extractTextChunk($text, $transformation->{start}[$chunk_start], $transformation->{end}[$chunk_end]);
                if ($from_components ne $in_resource) {
                    $self->{errors}{join(".", ($resource_id, $text_id, $chunk_id))} = "$from_components vs. $in_resource";
                }
            }
        }

        if (!scalar(keys %annotations)) {
            next;
        }

        ## (3) Find real chunks with the respect of correct XML tags,
        ## define instruction for marking in XML
        my %instructions = $self->_findBracketing(%annotations);

        ## (4) Annotate source text
        print STDERR "\n*** Annotations\n";
        my $annotated_text = _annotate(\%instructions, $text);

        ## (4.5) Transform HTML Entitie back
        $annotated_text =~ s/</&lt;/g;
        $annotated_text =~ s/>/&gt;/g;
        $annotated_text =~ s/&lt;p(.*?)&gt;/<p$1>/g;
        $annotated_text =~ s/&lt;\/p&gt;/<\/p>/g;
        $annotated_text =~ s/&lt;annotation id="(\d+)"&gt;/<annotation id="$1">/g;
        $annotated_text =~ s/&lt;\/annotation&gt;/<\/annotation>/g;

        my $annotated_text_colors = $annotated_text;
        $annotated_text_colors =~ s/(<annotation[^>]+>)/\033[1;31m$1/g;
        $annotated_text_colors =~ s/(<\/annotation>)/$1\033[0m/g;
        print STDERR "\tFINAL\t$annotated_text_colors\n";
        
        ## (5) Modify source XML document
        ## - create XML structure from $annotated_text
        ## - remove childs from source <p> and add new childs from $annotated_text
        eval {
            my $NewP = $Parser->parse_string($annotated_text);
            $p[$i]->removeChildNodes();
            foreach my $child ($NewP->firstChild()->childNodes()) {
                $p[$i]->appendChild($child);
            }
        };

        if ($@) {
            my $LOG = undef;
            open($LOG, ">>./servers/logs/export.log");
            RExtractor::Tools::warning($LOG, "Cannot parse annotated string for resource $i in document $Document->{id}");
            close($LOG);
            next;
        }

        ## Report annotation errors
        print STDERR "\n\n\n=======================================\n";
        print STDERR "ANNOTATION ERROS REPORT\n";
        print STDERR "==========================================\n\n\n";
        foreach my $id (sort keys %{$self->{errors}}) {
            print STDERR "$id\t$self->{errors}{$id}\n";
        }
    }

    return 1;
}

sub _findBracketing {
    my ($self, %annotations) = @_;

    # Create points
    my @points = ();
    foreach my $chunk_id (keys %annotations) {
        push(@points, {position => $annotations{$chunk_id}{start}, type => 'S', chunk_id => $chunk_id});
        push(@points, {position => $annotations{$chunk_id}{end}, type => 'E', chunk_id => $chunk_id});
    }
    @points = sort {$a->{position} <=> $b->{position}} @points;

    # Debug
    print STDERR "\n*** Points\n";
    foreach my $point (@points) {
        print STDERR "\t$point->{position}\t$point->{type}\t$point->{chunk_id}\n";
    }

    # Create annotation instruction
    print STDERR "\n*** Couples\n";
    my %instructions = ();
    my %open_chunks = ();
    for (my $i = 0; $i < scalar(@points) - 1; $i++) {
        # Update open_chunks set
        if ($points[$i]->{type} eq 'S') {
            $open_chunks{$points[$i]->{chunk_id}} = defined;
        }
        if ($points[$i]->{type} eq 'E') {
            delete($open_chunks{$points[$i]->{chunk_id}});
        }

        print STDERR "\t$points[$i]->{type} $points[$i + 1]->{type}\t{" . join(" ", keys %open_chunks) . "}\t";

        if (scalar(keys %open_chunks) and
            $points[$i + 1]->{position} - $points[$i]->{position} > 0) {
            $self->{resource_chunk_id}++;
            $instructions{$self->{resource_chunk_id}}{start} = $points[$i]->{position};
            $instructions{$self->{resource_chunk_id}}{end} = $points[$i + 1]->{position};
            foreach my $chunk_id (keys %open_chunks) {
                $instructions{$self->{resource_chunk_id}}{chunk_ids}{$chunk_id} = defined;
                $self->{annotations}{$chunk_id}{$self->{resource_chunk_id}} = defined;
            }
            print STDERR "=>\tANNOTATION\t$self->{resource_chunk_id}\t$instructions{$self->{resource_chunk_id}}{start}\t$instructions{$self->{resource_chunk_id}}{end}\t" . join(" ", keys %{$instructions{$self->{resource_chunk_id}}{chunk_ids}});
        }

        print STDERR "\n";
    }

    return %instructions;
}

sub _annotate {
    my ($instructions, $text) = @_;
    my $output_text = "";

    my $previous_offset = 0;
    foreach my $instruction (sort {$a <=> $b} keys %$instructions) {
        #print STDERR "Instruction: $instruction\n";

        # Take diference between previous and current start position
        my $before_tag = _extractTextChunk($text, $previous_offset, $instructions->{$instruction}{start});
        my $inside_tag = _extractTextChunk($text, $instructions->{$instruction}{start}, $instructions->{$instruction}{end});

        #print STDERR "Before: $before_tag\n";
        #print STDERR "Inside: $inside_tag\n";

        $output_text .= $before_tag . "<annotation id=\"$instruction\">" . $inside_tag . "</annotation>";
        $previous_offset = $instructions->{$instruction}{end};
    }
    $output_text .= _extractTextChunk($text, $previous_offset, length($text));

    return $output_text;
}

sub _transformOffset {
    my ($minus_offset, $text1, $text2) = @_;

    #print STDERR "\n*** Transformation\n";
    #print STDERR "\tInput text 1: '$text1'\n";
    #print STDERR "\tInput text 2: '$text2'\n";

    my $original_text2 = $text2;

    my @start_transformation = ();
    my @end_transformation = ();
    for (my $i = 0; $i < length($text2) + length($text1); $i++) {
        push(@start_transformation, $i - $minus_offset);
        push(@end_transformation, $i - $minus_offset);
    }

    while ($text2 =~ s/^([^<>]*)(<\/?p(?:[^>]*)>|^\(\d+\)\s*|^[a-z]+\s*\)\s*)(.*)$/$1$3/) {
        my $before = $1;
        my $middle = $2;
        my $after = $3;

        my $middle_regexp = $middle;
        $middle_regexp =~ s/(\(|\)|\.|\+|\*|\[|\])/\\$1/g;
        my $after_regexp = $after;
        $after_regexp =~ s/(\(|\)|\.|\+|\*|\[|\])/\\$1/g;

        my $transform_from = 0;
        if ($original_text2 =~ /^(.*)($middle_regexp)($after_regexp)$/) {
            my $original_text_before = $1;
            while ($original_text_before =~ s/^([^<>]*)(<\/?p(?:[^>]*)>|^\(\d+\)\s*|^[a-z]+\s*\)\s*)(.*)$/$1$3/) {
                # nothing
            }

            $transform_from = length($original_text_before);
        }
        $transform_from += $minus_offset;

        #print STDERR "\tModified text: '$text2'\n";
        #print STDERR "Add " . length($middle) . " from $transform_from\n";
        for (my $i = $transform_from; $i < scalar(@start_transformation); $i++) {
            next if ($i < 0);
            $start_transformation[$i] += length($middle);
        }
        for (my $i = $transform_from + 1; $i < scalar(@end_transformation); $i++) {
            $end_transformation[$i] += length($middle);
        }
    }

    #print STDERR "\n*** Final transformation: \n";
    #for (my $i = 0; $i < scalar(@start_transformation); $i++) {
    #    print STDERR "\t$i\t$start_transformation[$i]\t$end_transformation[$i]\n";
    #}

    return {start => \@start_transformation, end => \@end_transformation};
}

sub _extractTextChunk {
    my ($text, $start, $end) = @_;

    return substr($text, $start, ($end - $start));
}

sub saveDescription {
    my ($self, $Document, $Serialize, $output_file) = @_;

    # Create new XML doc
    my $Description = XML::LibXML::Document->new("1.0", "utf-8");
    my $root = $Description->createElement("document");
    $Description->setDocumentElement($root);

    # Empty metadata
    my $metadata = $Description->createElement("metadata");
    $root->appendChild($metadata);

    # Entities
    my $entities = $Description->createElement("entities");
    my @entities = $Document->{xml}->findnodes("/document/description/entities/entity");
    foreach my $entity (@entities) {
        my $entity_id = $entity->getAttribute("entity_id");
        my $dbe_id = $entity->getAttribute("dbe_id");
        my $chunk_ids = $entity->getAttribute("chunk_ids");
        my $nodes = $entity->getAttribute("nodes");

        # Obtain dependency tree from list of nodes
        my @dep_tree = $Serialize->list2tree($nodes);

        # Transform chunk ids to real chunk ids
        my %real_chunk_ids = ();
        foreach my $chunk_id (split(/ /, $chunk_ids)) {
            if (!defined($self->{annotations}{$chunk_id})) {
                next;
            }
            foreach my $real_chunk_id (sort {$a <=> $b} keys %{$self->{annotations}{$chunk_id}}) {
                $real_chunk_ids{$real_chunk_id} = defined;
            }
        }

        # Create XML elements
        my $entity_node = $self->{xml}->createElement("entity");
        $entity_node->setAttribute("entity_id", $entity_id);
        $entity_node->setAttribute("dbe_id", $dbe_id) if (defined($dbe_id));
        $entity_node->setAttribute("chunk_ids", join(" ", sort {$a <=> $b} keys %real_chunk_ids));

        my $deptree = $self->{xml}->createElement("dependency_tree");
        foreach my $node_data (@dep_tree) {
            my $node = $self->{xml}->createElement("node");
            $node->setAttribute("form", $node_data->{form});
            $node->setAttribute("lemma", $node_data->{lemma});
            $node->setAttribute("ord", $node_data->{ord});
            $node->setAttribute("parent", $node_data->{parent});
            $deptree->appendChild($node);
        }

        $entity_node->appendChild($deptree);
        $entities->appendChild($entity_node);
    }

    $root->appendChild($entities);

    # Relations
    my $relations = $Description->createElement("relations");
    my @relations = $Document->{xml}->findnodes("/document/description/relations/relation");
    foreach my $relation (@relations) {
        my $relation_id = $relation->getAttribute("relation_id");
        my $dbr_id = $relation->getAttribute("dbr_id");
        my $subject_ids = $relation->getAttribute("subject_ids");
        my $predicate_ids = $relation->getAttribute("predicate_ids");
        my $object_ids = $relation->getAttribute("object_ids");
        my $subject_concept = $relation->getAttribute("subject_concept");
        my $predicate_concept = $relation->getAttribute("predicate_concept");
        my $object_concept = $relation->getAttribute("object_concept");

        my $relation_node = $self->{xml}->createElement("relation");
        $relation_node->setAttribute("relation_id", $relation_id);
        $relation_node->setAttribute("dbr_id", $dbr_id);
        $relation_node->setAttribute("subject_ids", $subject_ids);
        $relation_node->setAttribute("subject_concept", $subject_concept);
        $relation_node->setAttribute("predicate_ids", $predicate_ids);
        $relation_node->setAttribute("predicate_concept", $predicate_concept);
        $relation_node->setAttribute("object_ids", $object_ids);
        $relation_node->setAttribute("object_concept", $object_concept);
        
        $relations->appendChild($relation_node);
    }

    $root->appendChild($relations);

    open(my $OUTPUT, ">$output_file");
    $Description->toFH($OUTPUT, 2);
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


sub save {
    my ($self, $filename) = @_;

    open(my $OUTPUT, ">$filename");
    $self->{xml}->toFH($OUTPUT, 2);
    close($OUTPUT);

    return 1;
}

1;
