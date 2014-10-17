#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;
use RExtractor::Export::INTLIB;

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

    ##
    ## Process output file
    ##

    # Open document
    my $Document = new RExtractor::Document();
    if (!$Document->load("./data/converted/$document->{id}.xml")) {
        RExtractor::Tools::error($LOG, "Couldn't load XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during loading XML document ($document->{id}).");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    # Parse existing date records in the Document
    if (!$Document->parseBody() or
        !$Document->parseResources() or
        !$Document->parseChunks() or
        !$Document->parseEntities()) {
        RExtractor::Tools::error($LOG, "Couldn't parse description records XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during pasring description records in XML document ($document->{id}).");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Load serialized Document
    my $Serialized = new RExtractor::Annotation::Serialize();
    if (!$Serialized->load("./data/serialized/$document->{id}.csv")) {
        RExtractor::Tools::error($LOG, "Couldn't open serialized file './data/serialized/$document->{id}.csv'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during loading Serialized file ($document->{id}).");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    my $Export = new RExtractor::Export::INTLIB();
    if (!$Export->load("./data/submitted/$document->{id}.html")) {
        RExtractor::Tools::error($LOG, "Couldn't open submitted HTML file './data/submitted/$document->{id}.html'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during loading submitted file ($document->{id}).");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    if (!$Export->export($Document, $Serialized)) {
        RExtractor::Tools::error($LOG, "Couldn't export annotation into file './data/submitted/$document->{id}.html'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "710 Error occured during export process ($document->{id}).");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    $Export->save("./data/exported/$document->{id}.html");
    $Export->saveDescription($Document, $Serialized, "./data/exported/$document->{id}.xml");

    ## Everything OK, log and unlock document
    RExtractor::Tools::info($LOG, "Export process for document $document->{id} finished.");
    RExtractor::Tools::setDocumentStatus($document->{id}, "720 Document exported sucessfully.");
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
        RExtractor::Tools::setDocumentStatus($id, "700 Export process started");

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