#!/usr/bin/perl

use strict;
use warnings;
use XML::LibXML;
use utf8;

package RExtractor::Relations::Annotation;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

# Load CSV
sub load {
    my ($self, $filename) = @_;
    $self->{pml_results} = [];

    if (!open(FILE, "<$filename")) {
        return 0;
    }
    while (<FILE>) {
        chomp($_);
        my @f = split(/\t/, $_);
        if (scalar(@f) < 2) {
            next;
        }

        push(@{$self->{pml_results}}, {query => shift(@f), nodes => [@f]});
    }
    close(FILE);

    return 1;
}

# Process each pmltq result
sub annotate {
    my ($self, $DBR, $Document, $Serialize) = @_;

    RESULT:
    foreach my $pmltq (@{$self->{pml_results}}) {
        print STDERR "\n\n";
        print STDERR "===========================\n";
        print STDERR "Query: $pmltq->{query}\n";
        print STDERR "Nodes: " . join(", ", @{$pmltq->{nodes}}) . "\n";
        print STDERR "===========================\n";
        print STDERR "\n";

        # For each what_mark command make of find existing annotation.
        # Into hash %pos2id store chunk ids for each position
        # which will be later transform into RDF triples.
        my %pos2id = ();
        foreach my $what_mark (@{$DBR->{queries}{$pmltq->{query}}{what_mark}}) {
            my $position = $what_mark->{position};
            my $node = ${$pmltq->{nodes}}[$what_mark->{position} - 1];

            print STDERR "\n\n";
            print STDERR "-----------------------\n";
            print STDERR "WHAT MARK\n";
            print STDERR "-----------------------\n";
            print STDERR "\n";
            print STDERR "Type: $what_mark->{type}\n";
            print STDERR "Position: $what_mark->{position}\n";
            print STDERR "Node: $node\n";
            print STDERR "\n\n";

            ##
            ## ENTITY
            ##

            # For entity just return ids of chunks where given node
            # appear.
            if ($what_mark->{type} eq "entity") {
                if (!defined($Document->{node2entity_id}{$node})) {
                    print STDERR "Couldn't find any entity for node '$node'\n";
                    next;
                }

                foreach my $entity_id (keys %{$Document->{node2entity_id}{$node}}) {
                    $pos2id{$position}{$entity_id} = defined;
                }

                print STDERR "Entities: \n";
                foreach my $entity_id (sort keys %{$pos2id{$position}}) {
                    print STDERR "\t - $entity_id\n";
                }

                next;
            }

            ##
            ## NODE
            ##

            # If already exist a chunk which annotate specified node, use its
            # id. Else create a new entity.
            if ($what_mark->{type} eq "node") {
                my $entity = $Document->createEntity($Serialize, [$node], undef);
                $pos2id{$position}{$entity} = defined;

                print STDERR "Entities: \n";
                foreach my $entity_id (sort keys %{$pos2id{$position}}) {
                    print STDERR "\t - $entity_id\n";
                }
            }

            ##
            ## TREE
            ##

            # Obtrain a list of nodes which are in the subtree with given
            # root. Create a new entity for given list or used existing.
            if ($what_mark->{type} eq "tree") {
                my $ra_nodes = $Serialize->tree2list($node);
                my $entity = $Document->createEntity($Serialize, $ra_nodes, undef);
                $pos2id{$position}{$entity} = defined;

                print STDERR "Entities: \n";
                foreach my $entity_id (sort keys %{$pos2id{$position}}) {
                    print STDERR "\t - $entity_id\n";
                }
            }
        }

        # Now, for each position we have entity ids.
        # Create a relation record into the Document
        my %ids = ();
        my %concepts = ();
        foreach my $rdf_def (@{$DBR->{queries}{$pmltq->{query}}{to_rdf}}) {
            # If there is no pos2id for given position,
            # log warning and skip
            if (defined($rdf_def->{chunk_id}) and $rdf_def->{chunk_id} =~ /\d/) {
                if (!defined($pos2id{$rdf_def->{chunk_id}})) {
                    print STDERR "[WARNING]\tNo entity for position $rdf_def->{chunk_id} (DBR: $pmltq->{query})\n";
                    next RESULT;
                }

                $ids{$rdf_def->{type}} = join(" ", sort keys %{$pos2id{$rdf_def->{chunk_id}}});
            }
            else {
                $ids{$rdf_def->{type}} = "";
            }

            $concepts{$rdf_def->{type}} = $rdf_def->{concept};
        }

        $Document->createRelation(
            $pmltq->{query},
            $ids{subject},
            $concepts{subject},
            $ids{predicate},
            $concepts{predicate},
            $ids{object},
            $concepts{object}
        );
    }
    
    return 1;
}

1;