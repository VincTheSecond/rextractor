#!/usr/bin/perl

## (c) 2014, Vincet Kriz, kriz@ufal.mff.cuni.cz
## This script implements HTTP and Web interface for RExtractor server.

use strict;
use warnings;

## Parse dates with this
use Date::Parse;

## Initialice CGI
my $Source = new CGI;
use CGI;

## Load RExtractor libraries
use RExtractor::Presentation::UI;
use RExtractor::Presentation::INTLIB;
use RExtractor::Commands;
use RExtractor::Document;
use RExtractor::Entities::DBE;
use RExtractor::Relations::DBR;

## -------------------------------------------------------------------------------
## HTTP INTERFACE
## -------------------------------------------------------------------------------

## Parse params from URL
my $COMMAND = $Source->url_param('command') ? $Source->url_param('command') : "";

## A.1 SERVER STATE
## For each component server return state (on/off)
if ($COMMAND eq "server-state") {
    print "Content-type: text/html\n\n";
    print "[OK]\n";
    foreach my $server ("Conversion", "NLP", "Entity", "Relation", "Export") {
        my $pid = RExtractor::Tools::readFile("./servers/pids/" . lc($server) . ".pid");
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("./servers/pids/" . lc($server) . ".pid");
        if ($pid and (time() - $mtime) < 30 * 60) {
            print "$server server is ON.\n";
        }
        else {
            print "$server server is OFF.\n";
        }
    }

    exit 0;
}

## B.1 DOCUMENT STATE
## Returns document state number and message.
## Returns submition time (YYYY-MM-DD HH:MM:SS).
if ($COMMAND eq "document-state") {
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Exit if document doesn't exists
    if (!RExtractor::Tools::findDocument($id)) {
        print "[ERROR]\nDocument doesn't exist.\n";
        exit 1;
    }

    # Read last file from the log
    print "[OK]\n" . RExtractor::Tools::getDocumentStatus($id) . "\n";

    # Print submition time
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("./data/submitted/$id.html");
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
    print "" . ($year + 1900) . "-" . sprintf("%02d", ($mon + 1)) . "-" . sprintf("%02d", $mday) . " " . sprintf("%02d", $hour) . ":" . sprintf("%02d", $min) . ":" . sprintf("%02d", $sec) . "\n";

    exit 0;
}

## B.2 SUBMIT NEW DOCUMENT
## Name of the document is in POST-variable doc_id
## Content of the document is in POST-variable doc_content
if ($COMMAND eq "document-submit") {
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");
    my $content = $Source->param("doc_content");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorect document id. See user guide for valid id format.\n";
        exit 1;
    }

    if (!$id or !$content) {
        print "[ERROR]\nEmpty document id or document concent.\n";
        exit 1;
    }

    # Fail if ID already exists in the system
    if (RExtractor::Tools::findDocument($id)) {
        print "[ERROR]\nDocument with ID $id already exists.\n";
        exit 1;
    }

    # Create a file into submitted dir, change permissions
    if (!open(FILE, ">./data/submitted/$id.html")) {
        print "[ERROR]\nCouldn't open file ./data/submitted/$id.html for writing.\n";
        exit 1;
    }
    print FILE $content;
    close(FILE);
    chmod(0777, "./data/submitted/$id.html");

    # Create log file, set status to 200 - Submited correctly.
    if (!RExtractor::Tools::setDocumentStatus($id, "200 Submited correctly.")) {
        print "[ERROR]\nError occured while creating log file '/data/logs/$id.log'\n";
        exit 1;
    }
    chmod(0777, "./data/logs/$id.log");

    print "[OK]\nSubmitted correctly.\n";

    exit 0;
}

## B.3 DOCUMENT DELETE
## Removes document from the system
if ($COMMAND eq "document-delete") {
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Check state of the document. Don't remove them if any
    # server work with the document.
    my $status = RExtractor::Tools::getDocumentStatus($id);
    if ($status =~ /^(300|400|500|600|700)/) {
        print "[ERROR]\nDocument is processing at this moment.\n";
        exit 1;
    }

    # Delete files with given id prefix
    system("rm ./data/converted/$id.* 2>/dev/null");
    system("rm ./data/exported/$id.* 2>/dev/null");
    system("rm ./data/logs/$id.* 2>/dev/null");
    system("rm ./data/submitted/$id.* 2>/dev/null");
    system("rm ./data/treex/$id.* 2>/dev/null");
    system("rm ./data/serialized/$id.* 2>/dev/null");
    system("rm ./servers/tmp/entity/$id.* 2>/dev/null");
    system("rm -rf ./servers/tmp/nlp/$id/ 2>/dev/null");
    system("rm ./servers/tmp/export/$id.* 2>/dev/null");
    system("rm ./servers/tmp/relation/$id.* 2>/dev/null");

    print "[OK]\nDeleted.\n";

    exit 0;
}

## C.1 CONTENT HTML
## Returns HTML version of document with chunks annotated by <span> tags
if ($COMMAND eq "content-html") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Check state of the document.
    # For unexported documents return message
    my $status = RExtractor::Tools::getDocumentStatus($id);
    if ($status !~ /^(720)/) {
        print "Document is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
        exit 0;
    }

    # Load document and return as HTML
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$id.html")) {
        print "An error occured during loading document.\n";
        exit 1;
    }

    # Return HTML presentation of the document
    print $Document->getHTML();
    exit 0;
}

## C.2 CONTENT CHUNKS
## Return data about specified chunk
if ($COMMAND eq "content-chunks") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->param("doc_id");
    my $chunk_id = $Source->param("chunk_id");

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    if ($chunk_id !~ /^\d+$/) {
        print "[ERROR]\nIncorrent chunk id.\n";
        exit 1;
    }

    # Load DBE
    my $DBE = new RExtractor::Entities::DBE();
    $DBE->load("./database/entities.xml");

    # Load document
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$doc_id.html")) {
        print "An error occured during loading document.\n";
        exit 1;
    }

    # Find entity
    if (!defined($Document->{chunk2entity}{$chunk_id})) {
        exit 0;
    }

    # Print data
    my @entity_ids = keys %{$Document->{chunk2entity}{$chunk_id}};
    foreach my $entity_id (@entity_ids) {
        my @entities = $Document->{description}->findnodes("//entity[\@entity_id = '$entity_id']");
        my @chunks = split(/\s+/, $entities[0]->getAttribute('chunk_ids'));
        my $dbe_id = $entities[0]->getAttribute('dbe_id');
        my $dbe = $DBE->getEntity($dbe_id);
        if (defined($dbe)) {
            print join("\t", ($entity_id, join(", ", @chunks), $dbe->{original_form}, $dbe->{type})) . "\n";
        }
        else {
            print join("\t", ($entity_id, join(", ", @chunks), "", "")) . "\n";
        }
        
    }

    exit 0;
}

## C.3 CONTENT RELATIONS
## Returns extracted relations
if ($COMMAND eq "content-relations") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Check state of the document.
    # For unconverted documents return message
    my $status = RExtractor::Tools::getDocumentStatus($id);
    if ($status !~ /^(720)/) {
        print "Document is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
        exit 0;
    }

    # Load DBR
    my $DBR = new RExtractor::Relations::DBR();
    $DBR->load("./database/relations.xml");
    $DBR->parseQueries();

    # Load document and return as HTML
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$id.html")) {
        print "[ERROR]\nAn error occured during loading document.\n";
        exit 1;
    }

    # Return HTML presentation of the document
    print $Document->getRelations($DBR);
    exit 0;
}

## D.1 EXPORT DOCUMENT
## Returns exported document
if ($COMMAND eq "export-document") {
    print "Content-type: text/html\n\n";

    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Open document and print it to stdout
    open(FILE, "<./data/exported/$id.html");
    while (<FILE>) {
        print $_;
    }
    close(FILE);

    exit 0;
}

## D.2 EXPORT DESCRIPTION
## Returns exported document
if ($COMMAND eq "export-description") {
    # Load params
    my $id = $Source->param("doc_id");

    # Check params
    if ($id !~ /^[A-Za-z0-9\._\-]+$/) {
        print "Content-type: text/html\n\n";
        print "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Open document and print it to stdout
    print "Content-type: text/xml\n\n";
    open(FILE, "<./data/exported/$id.xml");
    while (<FILE>) {
        print $_;
    }
    close(FILE);

    exit 0;
}

## E LIST OF FILES
## Returns list of ids of document which were processed by specified component
if ($COMMAND =~ /^list-(submit|convert|nlp|entity|relation|export)$/) {
    print "Content-type: text/html\n\n";

    # Obtain data
    my @list = ();
    @list = split(/\n/, `grep 200 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-submit");
    @list = split(/\n/, `grep 320 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-convert");
    @list = split(/\n/, `grep 420 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-nlp");
    @list = split(/\n/, `grep 520 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-entity");
    @list = split(/\n/, `grep 620 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-relation");
    @list = split(/\n/, `grep 720 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($COMMAND eq "list-export");

    # Load params
    my $fromDate = $Source->param("fromDate");
    my $toDate = $Source->param("toDate");
    my $fromDateTime = $Source->param("fromDateTime");
    my $toDateTime = $Source->param("toDateTime");

    # If no time constraints are defined, return list
    if ($COMMAND =~ /^list-(submit|convert|nlp|entity|relation|export)$/ and
        !defined($fromDate) and !defined($toDate) and
        !defined($fromDateTime) and !defined($toDateTime)) {
        print join("\n", @list);
        exit 0;
    }

    # Check params
    if (defined($fromDate) and $fromDate !~ /^\d{4}-\d{2}-\d{2}$/) {
        print "[ERROR]\nIncorrect fromDate. See user guide for valid fromDate format.\n";
        exit 1;
    }

    if (defined($toDate) and $toDate !~ /^\d{4}-\d{2}-\d{2}$/) {
        print "[ERROR]\nIncorrect toDate. See user guide for valid toDate format.\n";
        exit 1;
    }

    if (defined($fromDateTime) and $fromDateTime !~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
        print "[ERROR]\nIncorrect fromDateTime. See user guide for valid fromDateTime format.\n";
        exit 1;
    }

    if (defined($toDateTime) and $toDateTime !~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
        print "[ERROR]\nIncorrect toDateTime. See user guide for valid toDateTime format.\n";
        exit 1;
    }

    # Chceck valid combination of params
    my $valid = 0;
    if (( defined($fromDate) and !defined($toDate) and !defined($fromDateTime) and !defined($toDateTime)) or
        ( defined($fromDate) and  defined($toDate) and !defined($fromDateTime) and !defined($toDateTime)) or
        (!defined($fromDate) and !defined($toDate) and  defined($fromDateTime) and !defined($toDateTime)) or
        (!defined($fromDate) and !defined($toDate) and  defined($fromDateTime) and  defined($toDateTime))) {
        $valid = 1;
    }

    if (!$valid) {
        print "[ERROR]\nIncorrect combination of datetime constraints.\n";
        exit 1;
    }

    # Convert datetimes to unix timestamp
    my $from = defined($fromDate) ? str2time("$fromDate 00:00:00") : str2time($fromDateTime);
    my $to = defined($toDate) ? str2time("$toDate 23:59:59") : str2time($toDateTime);

    foreach my $id (@list) {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("data/logs/$id.log");

        if ($mtime >= $from and defined($to) and $mtime <= $to) {
            print "$id\n";
            next;
        }

        if ($mtime >= $from and !defined($to)) {
            print "$id\n";
        }
    }

    exit 0;
}

## E.7 LIST ALL
## Returns details about each submitted document
if ($COMMAND eq "list-all") {
    print "Content-type: text/html\n\n";

    my @list = split(/\n/, `grep 200 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`);
    my %data = ();
    foreach my $id (@list) {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("data/submitted/$id.html");
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
        $data{$id}{ctime} = $mtime;
        $data{$id}{data} = "$id\t" . ($year + 1900) . "-" . sprintf("%02d", ($mon + 1)) . "-" . sprintf("%02d", $mday) . " " . sprintf("%02d", $hour) . ":" . sprintf("%02d", $min) . ":" . sprintf("%02d", $sec) . "\t" . RExtractor::Tools::getDocumentStatus($id) . "\n";
    }

    # Sort
    foreach my $id (reverse sort {$data{$a}{ctime} <=> $data{$b}{ctime}} keys %data) {
        print $data{$id}{data};
    }

    exit 0;
}

## -------------------------------------------------------------------------------
## WEB INTERFACE
## -------------------------------------------------------------------------------

print "Content-type: text/html\n\n";

my $UI = new RExtractor::Presentation::UI();
print $UI->getHTMLHead();
print $UI->getHeader();

print "<div id='content'>";
print "<div id='left-column'>";
print $UI->getMenu();
print $UI->appletServerStatus();
print "</div>";

print "<div id='main-column'>";
print "</div>";

print "<div style='clear: both'></div>";
print "</div>";

print $UI->getFooter();
print $UI->getHTMLFoot();

