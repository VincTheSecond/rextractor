#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Presentation::DBE;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub formatDBE {
    my ($self, $DBE) = @_;
    my $output = "";

    foreach my $id (sort {$a <=> $b} keys %{$DBE->{dbe}}) {
        $output .= "<p class='dbe_entity'>Entity: <b>$DBE->{dbe}{$id}{original_form}</b><br>Lemmatized form: <b>$DBE->{dbe}{$id}{lemmatized}</b><br>";
        $output .= "Ontological Concept: <i>$DBE->{dbe}{$id}{type}</i><br>";
        $output .= "Tree query:<br><code>$DBE->{dbe}{$id}{pmltq}</code></p>";
    }

    return $output;
}

1;