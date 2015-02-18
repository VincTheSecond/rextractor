#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Presentation::Strategy;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub formatStrategy {
    my ($self, $Strategy) = @_;
    my $output = "";

    # Metadata
    $output .= "<h3>$Strategy->{metadata}{name}</h3>";
    $output .= "<p><i>$Strategy->{metadata}{description}</i></p>";

    # Conversion
    $output .= "<h4 class='sb_component_title'>Conversion Component</h4>";
    $output .= "<p class='sb_component_setting'>Package: <br><code>$Strategy->{conversion}{package}</code></p>";

    # NLP
    $output .= "<h4 class='sb_component_title'>NLP Component</h4>";
    $output .= "<p class='sb_component_setting'>Package: <br><code>$Strategy->{nlp}{package}</code></p>";
    $output .= "<p class='sb_component_setting'>Segmentation: <br><code>$Strategy->{nlp}{segmentation}</code></p>";
    $output .= "<p class='sb_component_setting'>Parsing: <br><code>$Strategy->{nlp}{morphology}</code></p>";

    # Entity
    $output .= "<h4 class='sb_component_title'>Entity Detection Component</h4>";
    $output .= "<p class='sb_component_setting'>Package: <br><code>$Strategy->{entities}{package}</code></p>";
    $output .= "<p class='sb_component_setting'>DBE: <br><code>$Strategy->{entities}{dbe_file}</code></p>";
    $output .= "<p class='sb_component_setting'>Detection: <br><code>$Strategy->{entities}{detection}</code></p>";

    # Relation
    $output .= "<h4 class='sb_component_title'>Relation Extraction Component</h4>";
    $output .= "<p class='sb_component_setting'>Package: <br><code>$Strategy->{relation}{package}</code></p>";
    $output .= "<p class='sb_component_setting'>DBR: <br><code>$Strategy->{relation}{dbr_file}</code></p>";
    $output .= "<p class='sb_component_setting'>Extraction: <br><code>$Strategy->{relation}{detection}</code></p>";

    return $output;
}

1;