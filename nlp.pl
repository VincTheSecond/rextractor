#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;
use RExtractor::Strategy;

$SIG{INT}  = \&_signalHandler;
$SIG{KILL} = \&_signalHandler;
$SIG{TERM} = \&_signalHandler;

_daemonize();

# Open log file
my $LOG = undef;
open($LOG, ">>./servers/logs/nlp.log");

# Terminate if there is another running nlp server
my $pid = RExtractor::Tools::readFile("./servers/pids/nlp.pid");
if ($pid and kill(0, $pid)) {
    RExtractor::Tools::error($LOG, "Another NLP server ($pid) is running. Terminating...\n");
    exit(1);
}

# Create own PID-file
if (!RExtractor::Tools::writeFile("./servers/pids/nlp.pid", $$)) {
    RExtractor::Tools::error($LOG, "Couldn't create a PID file. Terminating...");
    exit(1);
}

RExtractor::Tools::info($LOG, "NLP server ($$) started.");

# Process document
while (42) {
    # Obtain document
    my $document = _getDocument();

    # If there is no document, sleep for 5 secs
    if (!defined($document)) {
        system("touch servers/pids/nlp.pid");
        sleep(5);
        next;
    }

    RExtractor::Tools::info($LOG, "NLP processing of the document $document->{id} started.");

    # Obtain strategy id
    my $strategy_id = RExtractor::Tools::getDocumentStrategy($document->{id});

    # Load strategy
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        RExtractor::Tools::error($LOG, "Couldn't load strategy from './strategies/$strategy_id.xml'.");
        RExtractor::Tools::setDocumentStatus($document->{id}, "410 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    # Check, if Strategy configuration contains all needed attributes
    if (!$Strategy->check("nlp")) {
        RExtractor::Tools::error($LOG, "Strategy is incorrect or incomplete. ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "410 Couldn't load strategy.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    RExtractor::Tools::info($LOG, "Applying conversion strategy '$strategy_id'.");

    ## Load file
    my $Document = new RExtractor::Document();
    if (!$Document->load($document->{filename})) {
        system("rm -rf ./servers/tmp/nlp/$document->{id}");
        RExtractor::Tools::error($LOG, "Couldn't load document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "410 Error occured during loading document.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    eval("use $Strategy->{nlp}{package}");
    my $NLP = eval("new $Strategy->{nlp}{package}");
    if (!$NLP->process($Strategy, $Document)) {
        system("rm -rf ./servers/tmp/nlp/$document->{id}");
        RExtractor::Tools::error($LOG, "Error occured while treex processing of the document ($document->{id}).");
        RExtractor::Tools::error($LOG, `cat /tmp/treex.log`);
        RExtractor::Tools::setDocumentStatus($document->{id}, "410 Error occured during document processing in treex.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    ## Everything OK, log and unlock document
    system("rm -rf ./servers/tmp/nlp/$document->{id}");
    RExtractor::Tools::info($LOG, "NLP of the document $document->{id} finished.");
    RExtractor::Tools::setDocumentStatus($document->{id}, "420 Document processed successfully.");
    RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");

    system("touch servers/pids/nlp.pid");
}

##
## Obtaining document for nlp.
## 
## Document must not have a lock file, it should have
## own log file and last message in the log should be
## 320 Document converted successfully.
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
        if ($status !~ /^320/) {
            next;
        }

        ##
        ## At this point we have a new document for processing
        ##

        # Create lock file
        RExtractor::Tools::writeFile("./data/converted/$id.lock", "nlp");

        # Log
        RExtractor::Tools::setDocumentStatus($id, "400 Language processing started.");

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
    RExtractor::Tools::deleteFile("./servers/pids/nlp.pid");

    # Close log
    RExtractor::Tools::info($LOG, "Terminating NOW!");
    close($LOG);

    exit(0);
}