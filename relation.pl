#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;
use RExtractor::Strategy;
use RExtractor::Relations;
use RExtractor::Relations::DBR;

$SIG{INT}  = \&_signalHandler;
$SIG{KILL} = \&_signalHandler;
$SIG{TERM} = \&_signalHandler;

_daemonize();

# Open log file
my $LOG = undef;
open($LOG, ">>./servers/logs/relation.log");

# Terminate if there is another running relation server
my $pid = RExtractor::Tools::readFile("./servers/pids/relation.pid");
if ($pid and kill(0, $pid)) {
    RExtractor::Tools::error($LOG, "Another relation server ($pid) is running. Terminating...\n");
    exit(1);
}

# Create own PID-file
if (!RExtractor::Tools::writeFile("./servers/pids/relation.pid", $$)) {
    RExtractor::Tools::error($LOG, "Couldn't create a PID file. Terminating...");
    exit(1);
}

RExtractor::Tools::info($LOG, "Relation server ($$) started.");

# Process document
while (42) {
    # Obtain document
    my $document = _getDocument();

    # If there is no document, sleep for 5 secs
    if (!defined($document)) {
        system("touch servers/pids/relation.pid");
        sleep(5);
        next;
    }

    RExtractor::Tools::info($LOG, "Relation detection for document $document->{id} started.");

    # Obtain strategy id
    my $strategy_id = RExtractor::Tools::getDocumentStrategy($document->{id});

    # Load strategy
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        RExtractor::Tools::error($LOG, "Couldn't load strategy from './strategies/$strategy_id.xml'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Check, if Strategy configuration contains all needed attributes
    if (!$Strategy->check("entity")) {
        RExtractor::Tools::error($LOG, "Strategy is incorrect or incomplete. ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    RExtractor::Tools::info($LOG, "Applying entity detection strategy '$strategy_id'.");

    # Load DBR
    my $DBR = new RExtractor::Relations::DBR();
    if (!$DBR->load($Strategy->{relation}{dbr_file})) {
        RExtractor::Tools::error($LOG, "Couldn't load DBR from file '$Strategy->{relation}{dbr_file}'. Terminating...");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Couldn't load DBR.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    if (!$DBR->parseQueries()) {
        RExtractor::Tools::error($LOG, "Couldn't parse queries in the DBR '$Strategy->{relation}{dbr_file}'. Terminating...");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Couldn't parse DBR.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Open document
    my $Document = new RExtractor::Document();
    if (!$Document->load("./data/converted/$document->{id}.xml")) {
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't load XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during loading XML document.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Parse existing entities in the Document
    if (!$Document->parseChunks() or !$Document->parseEntities()) {
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't parse entities XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during pasring entities in XML document.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Load serialized Document
    my $Serialized = new RExtractor::Annotation::Serialize();
    if (!$Serialized->load("./data/serialized/$document->{id}.csv")) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't open serialized file './data/serialized/$document->{id}.csv'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during loading Serialized file.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Process
    eval("use $Strategy->{relation}{package}");
    my $Relation = eval("new $Strategy->{relation}{package}");
    if (!$Relation->process($Strategy, $Document, $Serialized, $DBR)) {
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Error occured while relation detection process in the document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during relation detection in treex.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    $Document->save("./servers/tmp/relation/$document->{id}.xml");

    ## Everything OK, log and unlock document
    system("mv ./servers/tmp/relation/$document->{id}.xml ./data/converted/$document->{id}.xml");
    system("rm ./servers/tmp/relation/$document->{id}.*");
    RExtractor::Tools::info($LOG, "Relation detection in the document $document->{id} finished.");
    RExtractor::Tools::setDocumentStatus($document->{id}, "620 Document annotated successfully.");
    RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");

    system("touch servers/pids/relation.pid");
}

##
## Obtaining document for relation.
## 
## Document must not have a lock file, it should have
## own log file and last message in the log should be
## 520.
##
sub _getDocument {
    foreach my $file (split(/\n/, `find ./data/treex/ -type f -name '*.treex.gz'`)) {
        # Extract ID
        my $id = $file;
        $id =~ s/(?:.*\/)?([^\/]+)\.treex.gz/$1/;

        # Check lock
        if (-f "./data/treex/$id.lock") {
            next;
        }

        # Check log
        if (not(-f "./data/logs/$id.log")) {
            next;
        }

        # Check last message in log
        my $status = RExtractor::Tools::getDocumentStatus($id);
        if ($status !~ /^520/) {
            next;
        }

        ##
        ## At this point we have a new document for processing
        ##

        # Create lock file
        RExtractor::Tools::writeFile("./data/treex/$id.lock", "relation");

        # Log
        RExtractor::Tools::setDocumentStatus($id, "600 Relation detection started.");

        # Return document id
        return {filename => $file, id => $id};
    }

    return undef;
}

sub _daemonize {
    fork and exit;
    POSIX::setsid();
    fork and exit;
    umask 0;
    close STDIN;
    close STDOUT;
    close STDERR;
}

sub _signalHandler {
    RExtractor::Tools::info($LOG, "Received terminating signal. Preparing for termination...");

    # Remove PID
    RExtractor::Tools::deleteFile("./servers/pids/relation.pid");

    # Close log
    RExtractor::Tools::info($LOG, "Terminating NOW!");
    close($LOG);

    exit(0);
}