#!/usr/bin/perl

use strict;
use warnings;
use XML::LibXML;
use utf8;

package RExtractor::Entities::Annotation;

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

    print STDERR "Number of loaded PMLTQ results: " . scalar(@{$self->{pml_results}}) . "\n";
    
    return 1;
}

# Process each pmltq result
sub annotate {
    my ($self, $Document, $Serialize) = @_;

    foreach my $pmltq (@{$self->{pml_results}}) {
        print STDERR "\n\n";
        print STDERR "===========================\n";
        print STDERR "Query: $pmltq->{query}\n";
        print STDERR "Nodes: " . join(", ", @{$pmltq->{nodes}}) . "\n";
        print STDERR "===========================\n";
        print STDERR "\n";

        $Document->createEntity($Serialize, $pmltq->{nodes}, $pmltq->{query});
    }

    return 1;
}

1;