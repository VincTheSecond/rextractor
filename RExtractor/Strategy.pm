#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Strategy;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub loadFile {
    my ($self, $filename) = @_;
    print STDERR "RExtractor::Strategy::loadFile(@_)\n";

    # Parse XML
    eval {
        $self->{xml} = XML::LibXML->load_xml(location => $filename);
    };
    if ($@) {
        $self->{error} = $@;
        return 0;
    }

    # METADATA
    foreach my $attribute ("name", "description") {
        $self->{metadata}{$attribute} = $self->_getValue("/strategy/metadata/$attribute");
        print "[STRATEGY] \$self->{metadata}{$attribute} = $self->{metadata}{$attribute}\n";
    }

    # CONVERSION
    foreach my $attribute ("package") {
        $self->{conversion}{$attribute} = $self->_getValue("/strategy/conversion/$attribute");
        print "[STRATEGY] \$self->{conversion}{$attribute} = $self->{conversion}{$attribute}\n";
    }

    # NLP
    foreach my $attribute ("package", "segmentation", "morphology") {
        $self->{nlp}{$attribute} = $self->_getValue("/strategy/nlp/$attribute");
        print "[STRATEGY] \$self->{nlp}{$attribute} = $self->{nlp}{$attribute}\n";
    }

    # ENTITIES
    foreach my $attribute ("package", "detection") {
        $self->{entities}{$attribute} = $self->_getValue("/strategy/entities/$attribute");
        print "[STRATEGY] \$self->{entities}{$attribute} = $self->{entities}{$attribute}\n";
    }

    # RELATIONS
    foreach my $attribute ("package", "dbr_file", "detection") {
        $self->{relation}{$attribute} = $self->_getValue("/strategy/relation/$attribute");
        print "[STRATEGY] \$self->{relation}{$attribute} = $self->{relation}{$attribute}\n";
    }

    # EXPORT
    foreach my $attribute ("package") {
        $self->{export}{$attribute} = $self->_getValue("/strategy/export/$attribute");
        print "[STRATEGY] \$self->{export}{$attribute} = $self->{export}{$attribute}\n";
    }

    return 1;
}

# TODO
# For each component we will check if all needed attributes are available and correct.
sub check {
    my ($self, $component) = @_;

    #return checkRelation() if ($component eq "relation");
    return 1;
}

# TODO
sub checkRelation {
    my ($self) = @_;

    # DBE exists
    #my $scenario = "./database/relations.scen";
    #if (not (-f $scenario)) {
    #    RExtractor::Tools::error($LOG, "Couldn't load relation detection scenario. Terminating...");
    #}

    # DBR exists
    #my $DBR_XML_FILE = "./database/relations.xml";
    #if (not (-f $DBR_XML_FILE)) {
    #    RExtractor::Tools::error($LOG, "Couldn't find Database of Relations (DBR). Terminating...");
    #}
}

sub _getValue() {
    my ($self, $path) = @_;

    my @nodes = $self->{xml}->findnodes($path);
    if (@nodes < 1) {
        return ""
    }

    return $nodes[0]->to_literal();
}

1;
