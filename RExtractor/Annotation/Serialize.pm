#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;
use utf8;

package RExtractor::Annotation::Serialize;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub load {
    my ($self, $filename) = @_;

    if (!open(FILE, "<$filename")) {
        return 0;
    }
    binmode(FILE, ":encoding(utf8)");

    # Correction in offsets
    my $offset = 0;

    while (<FILE>) {
        chomp($_);
        my @f = split(/\t/, $_);

        $self->{data}{$f[0]}{id} = $f[0];
        $self->{data}{$f[0]}{ord} = $f[1];
        $self->{data}{$f[0]}{form} = $f[2];
        $self->{data}{$f[0]}{lemma} = $f[3];
        $self->{data}{$f[0]}{parent} = $f[4];
        $self->{data}{$f[0]}{start} = $f[5] + $offset;
        $self->{data}{$f[0]}{end} = $f[6] + $offset;
    }

    close(FILE);
    return 1;
}

# Returns list of nodes which belong to a tree
# with given root-node.
sub tree2list {
    my ($self, $root) = @_;

    # Obtain a list of nodes from whole tree with
    # given node
    my $sentence_id = $root;
    $sentence_id =~ s/-[^-]+$//;
    print STDERR "list2tree(@_): Sentence id: $sentence_id\n";

    my @nodes = ();
    foreach my $node (keys %{$self->{data}}) {
        if ($node =~ /$sentence_id/) {
            push(@nodes, $node);
        }
    }
    print STDERR "list2tree(@_): Number of nodes: " . scalar(@nodes) . "\n";

    # Create ord2id mapping
    my %ord2id = ();
    foreach my $node (@nodes) {
        $ord2id{$self->{data}{$node}{ord}} = $node;
    }

    # Put node into final list if his parent belong into %parent
    my %output = ( $root => defined );
    my %parents = ( $self->{data}{$root}{ord} => defined );
    my $parent_count = 0;
    while ($parent_count != scalar(keys %parents)) {
        $parent_count = scalar(keys %parents);
        foreach my $node (@nodes) {
            if (defined($parents{$self->{data}{$node}{parent}})) {
                $parents{$self->{data}{$node}{ord}} = defined;
                $output{$node} = defined;
            }
        }
    }

    print STDERR "list2tree(@_): " . join(", ", keys %output) . "\n";
    return [keys %output];
}

# Return NLP dep. tree for given list of nodes
sub list2tree {
    my ($self, $nodehash) = @_;

    my @nodes = ();
    foreach my $node_id (split(/ /, $nodehash)) {
        push(@nodes, $self->{data}{$node_id});
    }

    # Sort nodes and create a new ord
    my %oldord2neword = ();
    my $ord = 0;
    foreach my $node (sort {$a->{ord} <=> $b->{ord}} @nodes) {
        $ord++;
        $oldord2neword{$node->{ord}} = $ord;
    }

    # If node has unknown parent, use 0
    my %newparents = ();
    foreach my $node (@nodes) {
        if (!defined($oldord2neword{$node->{parent}})) {
            $newparents{$node->{ord}} = 0;
            next;
        }

        $newparents{$node->{ord}} = $oldord2neword{$node->{parent}};
    }

    # Create output structure
    my @output = ();
    foreach my $node (sort {$a->{ord} <=> $b->{ord}} @nodes) {
        push(@output, {
            form => $node->{form},
            lemma => $node->{lemma},
            ord => $oldord2neword{$node->{ord}},
            parent => $newparents{$node->{ord}}
        });
    }

    return @output;
}

1;
