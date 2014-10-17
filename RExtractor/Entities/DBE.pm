#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;

package RExtractor::Entities::DBE;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

# Load DBE
sub load {
    my ($self, $filename) = @_;

    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename);
    };
    if ($@) {
        $self->{error} = $@;
        return 0;
    }

    return 1;
}

sub getEntity {
    my ($self, $dbe_id) = @_;

    if (!defined($dbe_id)) {
        return undef;
    }
    
    
    my @entities = $self->{xml}->findnodes("//entity[\@id = '$dbe_id']");
    if (scalar(@entities) != 1) {
        return undef;
    }

    my @types = $entities[0]->findnodes('./type');
    my @original_forms = $entities[0]->findnodes('./original_form');
    return {
        dbe_id => $dbe_id,
        type => $types[0]->to_literal(),
        original_form => $original_forms[0]->to_literal()
    };
}

# Parse data about specified query
sub parseQueries {
    my ($self) = @_;
    $self->{queries} = {};

    my @queries = $self->{xml}->findnodes("//query");
    foreach my $query (@queries) {
        my $id = $query->getAttribute("id");

        ## Nacitam si podrobnosti o dotaze
        my @what_mark = ();
        my @markings = $queries[0]->findnodes(".//annotate");
        foreach my $marking (@markings) {
            my $type = $marking->findnodes('./@type')->to_literal() . "";
            my $position = $marking->findnodes('./@position')->to_literal() . "";
    
            push (@what_mark, {type => $type, position => $position});
        }
    
        ## RDF transformation
        my @to_rdf = ();
        my @to_rdf_results = $queries[0]->findnodes(".//column");
        foreach my $node (@to_rdf_results) {
            my $what_rdf = {};
    
            my $type = $node->findnodes('./@type')->to_literal() . "";
            my $chunk_id = $node->findnodes('./@chunk_id')->to_literal() . "";
            my $concept = $node->findnodes('./@concept')->to_literal() . "";
    
            $what_rdf->{type} = $type;
            $what_rdf->{chunk_id} = $chunk_id;
            $what_rdf->{concept} = $concept;
    
            push (@to_rdf, $what_rdf);
        }

        $self->{queries}{$id}{what_mark} = \@what_mark;
        $self->{queries}{$id}{to_rdf} = \@to_rdf;
    }

    return 1;
}

1;