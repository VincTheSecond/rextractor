#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;
use RExtractor::Export;
use RExtractor::Strategy;

$SIG{INT}  = \&_signalHandler;
$SIG{KILL} = \&_signalHandler;
$SIG{TERM} = \&_signalHandler;

binmode(STDERR, ":encoding(utf8)");

_daemonize();

# Open log file
my $LOG = undef;
open($LOG, ">>./servers/logs/export.log");

# Terminate if there is another running export server
my $pid = RExtractor::Tools::readFile("./servers/pids/export.pid");
if ($pid and kill(0, $pid)) {
    RExtractor::Tools::error($LOG, "Another export server ($pid) is running. Terminating...\n");
    exit(1);
}

# Create own PID-file
if (!RExtractor::Tools::writeFile("./servers/pids/export.pid", $$)) {
    RExtractor::Tools::error($LOG, "Couldn't create a PID file. Terminating...");
    exit(1);
}

RExtractor::Tools::info($LOG, "Export server ($$) started.");

# Process document
while (42) {
    # Obtain document
    my $document = _getDocument();

    # If there is no document, sleep for 5 secs
    if (!defined($document)) {
        system("touch servers/pids/export.pid");
        sleep(5);
        next;
    }

    RExtractor::Tools::info($LOG, "Export process for document $document->{id} started.");

    # Obtain strategy id
    my $strategy_id = RExtractor::Tools::getDocumentStrategy($document->{id});

    # Load strategy
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        RExtractor::Tools::error($LOG, "Couldn't load strategy from './strategies/$strategy_id.xml'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    # Check, if Strategy configuration contains all needed attributes
    if (!$Strategy->check("export")) {
        RExtractor::Tools::error($LOG, "Strategy is incorrect or incomplete. ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    RExtractor::Tools::info($LOG, "Applying export strategy '$strategy_id'.");
    
    ##
    ## Process output file
    ##

    # Open document
    my $Document = new RExtractor::Document();
    if (!$Document->load("./data/converted/$document->{id}.xml")) {
        RExtractor::Tools::error($LOG, "Couldn't load XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during loading XML document.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    # Parse existing date records in the Document
    if (!$Document->parseBody() or
        !$Document->parseResources() or
        !$Document->parseChunks() or
        !$Document->parseEntities()) {
        RExtractor::Tools::error($LOG, "Couldn't parse description records XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during pasring description records in XML document.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Load serialized Document
    my $Serialized = new RExtractor::Annotation::Serialize();
    if (!$Serialized->load("./data/serialized/$document->{id}.csv")) {
        RExtractor::Tools::error($LOG, "Couldn't open serialized file './data/serialized/$document->{id}.csv'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during loading Serialized file.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    # Process
    eval("use $Strategy->{export}{package}");
    my $Export = eval("new $Strategy->{export}{package}");
    if (!$Export->process($Document, $Serialized)) {
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Error occured during export in the document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during export.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    ## Everything OK, log and unlock document
    RExtractor::Tools::info($LOG, "Export process for document $document->{id} finished.");
    RExtractor::Tools::setDocumentStatus($document->{id}, "720 Document exported successfully.");
    RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");

    system("touch servers/pids/export.pid");
}

##
## Obtaining document for export.
## 
## Document must not have a lock file, it should have
## own log file and last message in the log should be
## 620.
##
sub _getDocument {
    foreach my $file (split(/\n/, `find ./data/converted/ -type f -name '*.xml'`)) {
        # Extract ID
        my $id = $file;
        $id =~ s/(?:.*\/)?([^\/]+)\.xml/$1/;

        # Check lock
        if (-f "./data/converted/$id.lock") {
            next;
        }

        # Check log
        if (not(-f "./data/logs/$id.log")) {
            next;
        }

        # Check last message in log
        my $status = RExtractor::Tools::getDocumentStatus($id);
        if ($status !~ /^620/) {
            next;
        }

        ##
        ## At this point we have a new document for processing
        ##

        # Create lock file
        RExtractor::Tools::writeFile("./data/converted/$id.lock", "export");

        # Log
        RExtractor::Tools::setDocumentStatus($id, "700 Export process started.");

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
    RExtractor::Tools::deleteFile("./servers/pids/export.pid");

    # Close log
    RExtractor::Tools::info($LOG, "Terminating NOW!");
    close($LOG);

    exit(0);
}