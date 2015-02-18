#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

use RExtractor::Annotation::Serialize;

package RExtractor::Document;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

# Load document
sub load {
    my ($self, $filename) = @_;
    
    # Parse XML
    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename);
    };
    if ($@) {
        $self->{error} = $@;
        return 0;
    }

    # Document ID
    my $id = $filename;
    $id =~ s/(?:.*\/)?([^\/]+)\.xml/$1/;
    $self->{id} = $id;

    # Remember or create chunk node in description section
    my $chunks_node = undef;
    my @descriptions_nodes = $self->{xml}->findnodes("/document/description");
    $self->{xml_description} = $descriptions_nodes[0];

    my @chunks_nodes = $self->{xml}->findnodes("/document/description/chunks");
    if (!scalar(@chunks_nodes)) {
        #print STDERR "Creating new <chunks> element.\n";
        $chunks_node = $self->{xml}->createElement("chunks");
        $descriptions_nodes[0]->appendChild($chunks_node);
    }
    else {
        $chunks_node = $chunks_nodes[0];
    }
    $self->{xml_chunks} = $chunks_node;

    # Create entities section, if doesn't exist
    my $entities_node = undef;
    my @entities_nodes = $self->{xml}->findnodes("/document/description/entities");
    if (!scalar(@entities_nodes)) {
        #print STDERR "Creating new <entities> element.\n";
        $entities_node = $self->{xml}->createElement("entities");
        $descriptions_nodes[0]->appendChild($entities_node);
    }
    else {
        $entities_node = $entities_nodes[0];
    }
    $self->{xml_entities} = $entities_node;

    # Create relations section, if doesn't exist
    my $relations_node = undef;
    my @relations_nodes = $self->{xml}->findnodes("/document/description/relations");
    if (!scalar(@relations_nodes)) {
        #print STDERR "Creating new <relations> element.\n";
        $relations_node = $self->{xml}->createElement("relations");
        $descriptions_nodes[0]->appendChild($relations_node);
    }
    else {
        $relations_node = $relations_nodes[0];
    }
    $self->{xml_relations} = $relations_node;
    
    return 1;
}

sub parseRelations {
    my ($self) = @_;
    $self->{max_used_relation_id} = 0;

    my @relations = $self->{xml}->findnodes("/document/description/relations/relation");
    foreach my $relation (@relations) {
        my $relation_id = $relation->getAttribute("relation_id");

        # max_used_id
        if ($relation_id > $self->{max_used_relation_id}) {
            $self->{max_used_relation_id} = $relation_id;
        }
    }

    return 1;
}

# For each node we want to extract chunks_ids where
# node appears. Remember maximal used chunk_id.
sub parseChunks {
    my ($self) = @_;
    $self->{max_used_chunk_id} = 0;
    $self->{node2chunk_id} = {};
    $self->{nodes2chunk_id} = {};

    my @chunks = $self->{xml}->findnodes("/document/description/chunks/chunk");
    foreach my $chunk (@chunks) {
        my $chunk_id = $chunk->getAttribute("chunk_id");
        my $nodes = $chunk->getAttribute("nodes");

        # max_used_id
        if ($chunk_id > $self->{max_used_chunk_id}) {
            $self->{max_used_chunk_id} = $chunk_id;
        }

        # node2chunk
        my @nodes = split(/\s+/, $nodes);
        foreach my $node (@nodes) {
            $self->{node2chunk_id}{$node}{$chunk_id} = defined;
        }

        # nodes2chunk_id
        $self->{nodes2chunk_id}{join(" ", sort @nodes)} = $chunk_id;
    }

    return 1;
}

# For given sequence of nodes create new chunk
# or return chunk_id if chunk already exists.
sub createChunk {
    my ($self, $Serialized, $ra_nodes) = @_;

    ##
    ## CHECK EXISTING CHUNKS
    ##

    # Create a node-hash
    # Return id of existing entity if given node sequence already
    # is annotated
    my $nodehash = join(" ", sort @{$ra_nodes});
    if (defined($self->{nodes2chunk_id}{$nodehash})) {
        return $self->{nodes2chunk_id}{$nodehash};
    }

    ##
    ## CREATE NEW CHUNK
    ##

    # From the first node obtain text_id
    my $text_id = $$ra_nodes[0];
    $text_id =~ s/^a_tree-(?:en|cs)-(\d+)-.*$/$1/;
    $text_id =~ s/^0+//;

    # Make annotation record
    $self->{max_used_chunk_id}++;

    my $chunk_id = $self->{max_used_chunk_id};
    my $chunk_node = $self->{xml}->createElement("chunk");
    $chunk_node->setAttribute("text_id", $text_id);
    $chunk_node->setAttribute("chunk_id", $chunk_id);
    $chunk_node->setAttribute("start", $Serialized->{data}{$$ra_nodes[0]}{start});
    $chunk_node->setAttribute("end", $Serialized->{data}{$$ra_nodes[scalar(@{$ra_nodes}) - 1]}{end});
    $chunk_node->setAttribute("nodes", join(" ", @{$ra_nodes}));

    $self->{xml_chunks}->appendChild($chunk_node);

    ##
    ## UPDATE DATA ABOUT CHUNKS
    ##

    # node2chunk
    foreach my $node (@{$ra_nodes}) {
        $self->{node2chunk}{$node}{$chunk_id} = defined;
    }

    # nodes2chunk_id
    $self->{nodes2chunk_id}{$nodehash} = $chunk_id;

    return $chunk_id;
}

# Parse resourses section in the document.
# Create a mapping with info, which text_ids
# contains given resource.
sub parseResources {
    my ($self) = @_;
    $self->{resource2text_id} = {};

    my @resources = $self->{xml}->findnodes("/document/description/resources/resource");
    foreach my $resource (@resources) {
        my $resource_id = $resource->getAttribute("resource");
        my $text_id = $resource->getAttribute("text_id");
        my $start = $resource->getAttribute("start");
        my $end = $resource->getAttribute("end");

        $self->{resource2text_id}{$resource_id}{$text_id}{start} = $start;
        $self->{resource2text_id}{$resource_id}{$text_id}{end} = $end;
    }

    print STDERR "Parse resources finished. Number of resource records = " . scalar(@resources) . "\n";
    return 1;
}

# For each node we want to extract ids of chunks where
# node appears. Remember maximal used chunk_id.
sub parseBody {
    my ($self) = @_;
    $self->{body} = {};

    my @texts = $self->{xml}->findnodes("/document/body/text");
    foreach my $text (@texts) {
        my $text_id = $text->getAttribute("id");
        $self->{body}{$text_id} = $text->to_literal();
    }

    print STDERR "Parse body finished. Number of text elements: " . scalar(keys %{$self->{body}}) . "\n";
    return 1;
}


# For each node we want to extract ids of chunks where
# node appears. Remember maximal used chunk_id.
sub parseEntities {
    my ($self) = @_;
    $self->{max_used_entity_id} = 0;
    $self->{node2entity_id} = {};
    $self->{nodes2entity_id} = {};

    my @entities = $self->{xml}->findnodes("/document/description/entities/entity");
    foreach my $entity (@entities) {
        my $entity_id = $entity->getAttribute("entity_id");
        my $chunk_ids = $entity->getAttribute("chunk_ids");
        my $nodes = $entity->getAttribute("nodes");

        # max_used_entity_id
        if ($entity_id > $self->{max_used_entity_id}) {
            $self->{max_used_entity_id} = $entity_id;
        }

        # node2entity_id
        my @nodes = split(/\s+/, $nodes);
        foreach my $node (@nodes) {
            $self->{node2entity_id}{$node}{$entity_id} = defined;
        }

        # nodes2entity_id
        $self->{nodes2entity_id}{join(" ", sort @nodes)} = $entity_id;
    }

    print STDERR "Parse entities finished. max_used_entity_id = $self->{max_used_entity_id}\n";
    return 1;
}

# For given sequence of nodes create new entity
# or return id of the entity which already exists.
sub createEntity {
    my ($self, $Serialize, $ra_nodes, $dbe_id) = @_;

    ##
    ## FIND CONTINUOUSED SEQUENCES
    ##

    # For each entity find continuouse sequences of nodes
    my @nodes = sort @{$ra_nodes};
    my @sequences = ([shift(@nodes)]);
    foreach my $node (@nodes) {
        my $curr_node_num = $node;
        $curr_node_num =~ s/.*n(\d+)$/$1/;

        my $last_sequence = $sequences[scalar(@sequences) - 1];
        my $prev_node_num = $$last_sequence[scalar(@{$last_sequence}) - 1];
        $prev_node_num =~ s/.*n(\d+)$/$1/;

        if ($curr_node_num == $prev_node_num + 1) {
            push(@{$sequences[scalar(@sequences) - 1]}, $node);
        }
        else {
            push(@sequences, [$node]);
        }
    }

    ##
    ## CHECK EXISTING ENTITIES
    ##

    # Create a node-hash
    # Return id of existing entity if given node sequence already
    # is annotated
    my $nodehash = join(" ", sort @{$ra_nodes});
    if (defined($self->{nodes2entity_id}{$nodehash})) {
        return $self->{nodes2entity_id}{$nodehash};
    }

    ##
    ## CREATE NEW ENTITY
    ##

    # Create or find existing chunk for each node sequence
    my @chunk_ids = ();
    foreach my $sequence (@sequences) {
        push(@chunk_ids, $self->createChunk($Serialize, $sequence));
    }

    # Make entity record
    $self->{max_used_entity_id}++;
    my $entity_id = $self->{max_used_entity_id};
    my $entity_node = $self->{xml}->createElement("entity");
    $entity_node->setAttribute("entity_id", $entity_id);
    $entity_node->setAttribute("dbe_id", $dbe_id) if (defined($dbe_id));
    $entity_node->setAttribute("chunk_ids", join(" ", @chunk_ids));
    $entity_node->setAttribute("nodes", $nodehash);

    $self->{xml_entities}->appendChild($entity_node);

    ##
    ## UPDATE DATA ABOUT ENTITIES
    ##

    # node2entity_id
    foreach my $node (@{$ra_nodes}) {
        $self->{node2entity_id}{$node}{$entity_id} = defined;
    }

    # nodes2entity_id
    $self->{nodes2entity_id}{$nodehash} = $entity_id;

    return $entity_id;
}

sub createRelation {
    my ($self, $dbr_id, $subject_ids, $subject_concept, $predicate_ids, $predicate_concept, $object_ids, $object_concept) = @_;

    # Make entity record
    $self->{max_used_relation_id}++;
    my $relation_id = $self->{max_used_relation_id};
    my $relation_node = $self->{xml}->createElement("relation");
    $relation_node->setAttribute("relation_id", $relation_id);
    $relation_node->setAttribute("dbr_id", $dbr_id);
    $relation_node->setAttribute("subject_ids", $subject_ids);
    $relation_node->setAttribute("subject_concept", $subject_concept);
    $relation_node->setAttribute("predicate_ids", $predicate_ids);
    $relation_node->setAttribute("predicate_concept", $predicate_concept);
    $relation_node->setAttribute("object_ids", $object_ids);
    $relation_node->setAttribute("object_concept", $object_concept);

    $self->{xml_relations}->appendChild($relation_node);

    return $relation_id;
}

sub save {
    my ($self, $filename) = @_;

    open(my $OUTPUT, ">$filename");
    $self->{xml}->toFH($OUTPUT, 2);
    close($OUTPUT);

    return 1;
}

1;
