#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;
#use RExtractor::Entities::DBE;
use RExtractor::Relations::DBR;
use RExtractor::Relations::Annotation;

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

# Load DBE
my $scenario = "./database/relations.scen";
if (not (-f $scenario)) {
    RExtractor::Tools::error($LOG, "Couldn't load relation detection scenario. Terminating...");
    exit(1);
}

##
## Load DBR
## 
my $DBR_XML_FILE = "./database/relations.xml";
if (not (-f $DBR_XML_FILE)) {
    RExtractor::Tools::error($LOG, "Couldn't find Database of Relations (DBR). Terminating...");
    exit(1);
}

my $DBR = new RExtractor::Relations::DBR();
if (!$DBR->load($DBR_XML_FILE)) {
    RExtractor::Tools::error($LOG, "Couldn't load Database of Relations (DBR). Terminating...");
    exit(1);
}

if (!$DBR->parseQueries()) {
    RExtractor::Tools::error($LOG, "Couldn't parse queries in the Database of Relations (DBR). Terminating...");
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

    ##
    ## Run treex
    ##

    my $output_file = "./servers/tmp/relation/$document->{id}.csv";
    my $treex_return_value = system("
        export TMT_ROOT=/data/intlib/treex/;
        export TRED_DIR=\"/data/intlib/tred\";
        export TRED_DEPENDENCIES=\"/data/intlib/tred/dependencies\";
        PATH=\"\${TRED_DEPENDENCIES}/bin:\${PATH}\";
        export PERL5LIB=\"\${TRED_DEPENDENCIES}/lib/perl5\${PERL5LIB:+:\$PERL5LIB}\";
        export LD_LIBRARY_PATH=\"\${TRED_DEPENDENCIES}/lib:\${LD_LIBRARY_PATH}\";
        treex $scenario Write::Treex clobber=1 -- $document->{filename} >$output_file"
    );
    if ($treex_return_value) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Error occured while relation detection process in the document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during relation detection in treex.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    ##
    ## Process output file with entities
    ##

    # Open document
    my $Document = new RExtractor::Document();
    print STDERR "File: ./data/converted/$document->{id}.xml\n";
    if (!$Document->load("./data/converted/$document->{id}.xml")) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't load XML document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during loading XML document.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    # Parse existing entities in the Document
    if (!$Document->parseChunks() or !$Document->parseEntities()) {
        # Delete tmp files
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

    # Annotate relations into Document
    my $Annotate = new RExtractor::Relations::Annotation();

    if (!$Annotate->load($output_file)) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't load PMLTQ results from file '$output_file' ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during parsing PMLTQ results for document.");
        RExtractor::Tools::deleteFile("./data/treex/$document->{id}.lock");
        next;
    }

    if (!$Annotate->annotate($DBR, $Document, $Serialized)) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/relation/$document->{id}.csv");
        RExtractor::Tools::error($LOG, "Couldn't save relations annotations in document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "610 Error occured during annotating relations in document.");
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