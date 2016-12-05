#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Presentation::DBR;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub formatDBR {
    my ($self, $DBR) = @_;
    my $output = "";

    foreach my $id (sort {$a <=> $b} keys %{$DBR->{queries}}) {
        $output .= "<div class='dbr_entity'>";
        $output .= "<p>";
        $output .= "Query: <b>$DBR->{queries}{$id}{description}</b><br>";
        $output .= "How to process result tree nodes from PMLTQ: <br><ul>";
        foreach my $what_mark (@{$DBR->{queries}{$id}{what_mark}}) {
            $output .= "<li>Node $what_mark->{position} is $what_mark->{type}";
        }
        $output .= "</ul>";
        $output .= "RDF transformation of result:<br><ul>";
        foreach my $to_rdf (@{$DBR->{queries}{$id}{to_rdf}}) {
            $output .= "<li>Element $to_rdf->{type} is instance of Ontological class $to_rdf->{concept}";
        }
        $output .= "</ul>";
        $output .= "Tree query:<br><code>$DBR->{queries}{$id}{pmltq}</code></p>";
        $output .= "</div>";
    }
    
    return $output;
}

1;