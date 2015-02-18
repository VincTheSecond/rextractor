#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
#use utf8;

package RExtractor::Relations::DBR;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

# Load DBR
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

# Parse data about specified query
sub parseQueries {
    my ($self) = @_;
    $self->{queries} = {};

    my @queries = $self->{xml}->findnodes("//query");
    foreach my $query (@queries) {
        my $id = $query->getAttribute("id");

        my @descriptions = $query->findnodes("./description");
        my $description = $descriptions[0]->to_literal();

        ## Nacitam si podrobnosti o dotaze
        my @what_mark = ();
        my @markings = $query->findnodes("./annotations/annotate");
        foreach my $marking (@markings) {
            my $type = $marking->findnodes('./@type')->to_literal() . "";
            my $position = $marking->findnodes('./@position')->to_literal() . "";
    
            push (@what_mark, {type => $type, position => $position});
        }
    
        ## RDF transformation
        my @to_rdf = ();
        my @to_rdf_results = $query->findnodes("./result/column");
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

        $self->{queries}{$id}{description} = $description;
        $self->{queries}{$id}{what_mark} = \@what_mark;
        $self->{queries}{$id}{to_rdf} = \@to_rdf;
        $self->{queries}{$id}{pmltq} = $query->findnodes("./pml_tq")->to_literal();
    }

    #print STDERR "Number of parsed queries: " . scalar(keys %{$self->{queries}}) . "\n";
    #foreach my $id (sort keys %{$self->{queries}}) {
    #    print STDERR "$id\n";
    #    print STDERR "\t" . join(", ", map {$_->{position} . ":" . $_->{type}} @{$self->{queries}{$id}{what_mark}}) . "\n";
    #    print STDERR "\t" . join(", ", map {$_->{chunk_id} . ":" . $_->{concept}} @{$self->{queries}{$id}{to_rdf}}) . "\n";
    #}

    return 1;
}

1;