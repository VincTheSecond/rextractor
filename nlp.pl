#!/usr/bin/perl

use strict;
use warnings;
use POSIX;

use RExtractor::Tools;
use RExtractor::Document;

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

    ## Load file
    my $Document = new RExtractor::Document();
    $Document->load($document->{filename});

    ## Create temporary dir structure
    print STDERR "Creating temporary dirs...\n";
    system("mkdir ./servers/tmp/nlp/$document->{id}");
    system("mkdir ./servers/tmp/nlp/$document->{id}/txt");
    system("mkdir ./servers/tmp/nlp/$document->{id}/segmented");
    
    ## Create input files for Treex
    print STDERR "Creating txt files...\n";
    my @texts = $Document->{xml}->findnodes("/document/body/text");
    foreach my $textnode (@texts) {
        my $id = $textnode->getAttribute("id");
        my $text = $textnode->to_literal();

        open(FILE, ">./servers/tmp/nlp/$document->{id}/txt/$document->{id}" . "_" . sprintf("%04d", $id) . ".txt");
        binmode(FILE, ":encoding(utf-8)");
        print FILE $text;
        close(FILE);
    }

    ## Run Treex segmentation
    print STDERR "Run segmentation...\n";
    my $tree1_return_value = system("export TMT_ROOT=/data/intlib/treex/; treex Util::SetGlobal language=cs Read::Text from='!./servers/tmp/nlp/$document->{id}/txt/*.txt' W2A::CS::Segment Write::Treex compress=0");
    if ($tree1_return_value) {
        # Delete tmp files
        system("rm -rf ./servers/tmp/nlp/$document->{id}");
        RExtractor::Tools::error($LOG, "Error occured while treex processing of the document ($document->{id}).");
        RExtractor::Tools::setDocumentStatus($document->{id}, "410 Error occured during document processing in treex.");
        RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");
        next;
    }

    ## Read data from treex files
    my @LMs = ();
    print STDERR "Merge treex files...\n";
    foreach my $file (split(/\n/, `find ./servers/tmp/nlp/$document->{id}/txt/ -name '*.treex' | sort`)) {
        my $subid = $file;
        $subid =~ s/^.*_(\d+)\.treex$/$1/;

        my $lm_section = 0;
        my $data = "";
        open(FILE, "<$file");
        while (<FILE>) {
            chomp($_);
            if ($_ =~ /<LM id="/) {
                $_ =~ s/id="(.*)"/id="$subid-$1"/;
                $lm_section = 1;
            }

            if ($lm_section) {
                $data .= "$_\n";
            }

            if ($_ =~ /<\/LM>/) {
                $lm_section = 0;
            }
        }
        close(FILE);

        push(@LMs, $data);
    }

    ## Merge treex files into one
    my $treex_file = "./servers/tmp/nlp/$document->{id}/segmented/$document->{id}.treex";
    open(OUTPUT, ">$treex_file");
    print OUTPUT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<treex_document xmlns=\"http://ufal.mff.cuni.cz/pdt/pml/\">
  <head>
    <schema href=\"treex_schema.xml\" />
  </head>
  <bundles>\n";
    print OUTPUT join("\n", @LMs) . "\n";
    print OUTPUT "  </bundles>
</treex_document>
    ";
    close(OUTPUT);

    ## Run morphlogy and other stuff over merded file
    print STDERR "Run treex...\n";
    my $treex_output_file = "./data/treex/$document->{id}.treex.gz";
    my $csv_output_file = "./data/serialized/$document->{id}.csv";

    my $tree2_return_value = system("export TMT_ROOT=/data/intlib/treex/; treex W2A::CS::Tokenize W2A::CS::TagFeaturama lemmatize=1 W2A::CS::FixMorphoErrors INTLIB::Retokenize W2A::CS::ParseMSTAdapted W2A::CS::FixAtreeAfterMcD W2A::CS::FixIsMember W2A::CS::FixPrepositionalCase W2A::CS::FixReflexiveTantum W2A::CS::FixReflexivePronouns INTLIB::Serialize to=$csv_output_file Write::Treex to=$treex_output_file -- $treex_file 2>/tmp/treex.log");
    if ($tree2_return_value) {
        # Delete tmp files
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
    RExtractor::Tools::setDocumentStatus($document->{id}, "420 Document processed sucessfully.");
    RExtractor::Tools::deleteFile("./data/converted/$document->{id}.lock");

    system("touch servers/pids/nlp.pid");
}

##
## Obtaining document for nlp.
## 
## Document must not have a lock file, it should have
## own log file and last message in the log should be
## 320 Document converted sucessfully.
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
        RExtractor::Tools::setDocumentStatus($id, "400 Language processing started");

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