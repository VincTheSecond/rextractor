#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Conversion::INTLIB;

$SIG{INT}  = \&_signalHandler;
$SIG{KILL} = \&_signalHandler;
$SIG{TERM} = \&_signalHandler;

_daemonize();

# Open log file
my $LOG = undef;
open($LOG, ">>./servers/logs/conversion.log");

# Terminate if there is another running conversion server
my $pid = RExtractor::Tools::readFile("./servers/pids/conversion.pid");
if ($pid and kill(0, $pid)) {
    RExtractor::Tools::error($LOG, "Another conversion server ($pid) is running. Terminating...\n");
    exit(1);
}

# Create own PID-file
if (!RExtractor::Tools::writeFile("./servers/pids/conversion.pid", $$)) {
    RExtractor::Tools::error($LOG, "Couldn't create a PID file. Terminating...");
    exit(1);
}

RExtractor::Tools::info($LOG, "Conversion server ($$) started.");

# Here will be a hash with processed and unusable documents
my %processed = ();

# Process document
while (42) {
    # Obtain document
    my $document = _getDocument();

    # If there is no document, sleep for 5 secs
    if (!defined($document)) {
        system("touch servers/pids/conversion.pid");
        sleep(5);
        next;
    }

    RExtractor::Tools::info($LOG, "Conversion of the document $document->{id} started.");

    # If there is document, start conversion
    my $Convertor = new RExtractor::Conversion::INTLIB();
    if (!$Convertor->loadFile($document->{filename})) {
        RExtractor::Tools::error($LOG, "Error occured while parsing XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "310 Error occured during document conversion.");
        RExtractor::Tools::deleteFile("./data/submitted/$document->{id}.lock");
        next;
    }

    # Log error, unlock document, if conversion was not successful
    if (!$Convertor->convert()) {
        RExtractor::Tools::error($LOG, "Error occured while conversion document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "310 Error occured during document conversion.");
        RExtractor::Tools::deleteFile("./data/submitted/$document->{id}.lock");
        next;
    }

    ## Save and unlock document
    $Convertor->saveFile("./data/converted/$document->{id}.xml");
    RExtractor::Tools::info($LOG, "Conversion of the document $document->{id} finished.");
    RExtractor::Tools::setDocumentStatus($document->{id}, "320 Document converted sucessfully.");
    RExtractor::Tools::deleteFile("./data/submitted/$document->{id}.lock");

    $processed{$document->{id}} = defined;
    system("touch servers/pids/conversion.pid");
}

##
## Obtaining document for conversion.
## 
## Document must not have a lock file, it should have
## own log file and last message in the log should be
## 200 Submited.
##
sub _getDocument {
    foreach my $file (split(/\n/, `find ./data/submitted/ -type f -name '*.html'`)) {
        # Extract ID
        my $id = $file;
        $id =~ s/(?:.*\/)?([^\/]+)\.html/$1/;

        # Chceck processed hash
        if (defined($processed{$id})) {
            next;
        }

        # Check lock
        if (-f "./data/submitted/$id.lock") {
            next;
        }

        # Check log
        if (not(-f "./data/logs/$id.log")) {
            next;
        }

        # Check last message in log
        my $status = RExtractor::Tools::getDocumentStatus($id);
        if ($status !~ /^200/) {
            $processed{$id} = defined;
            next;
        }

        ##
        ## At this point we have a new document for processing
        ##

        # Create lock file
        RExtractor::Tools::writeFile("./data/submitted/$id.lock", "conversion");

        # Log
        RExtractor::Tools::setDocumentStatus($id, "300 Conversion started");

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
    RExtractor::Tools::deleteFile("./servers/pids/conversion.pid");

    # Close log
    RExtractor::Tools::info($LOG, "Terminating NOW!");
    close($LOG);

    exit(0);
}