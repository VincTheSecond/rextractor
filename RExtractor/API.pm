#!/usr/bin/perl

use strict;
use warnings;
use Date::Parse;

use RExtractor::Relations::DBR;
use RExtractor::Entities::DBE;
use RExtractor::Presentation::INTLIB;
use RExtractor::Presentation::Strategy;
use RExtractor::Presentation::DBE;
use RExtractor::Presentation::DBR;
use RExtractor::Strategy;

package RExtractor::API;

## A.1 SERVER START
## Start each RExtractor daemon
sub a1_server_start {
    system("./conversion.pl");
    system("./nlp.pl");
    system("./entity.pl");
    system("./relation.pl");
    system("./export.pl");
}

## A.2 SERVER STOP
## Send terminating signal to each RExtractor daemon.
sub a2_server_stop {
    my $existing_off = 0;
    foreach my $server ("Conversion", "NLP", "Entity", "Relation", "Export") {
        my $pid = RExtractor::Tools::readFile("./servers/pids/" . lc($server) . ".pid");
        kill("INT", $pid);
    }
}

## A.3 SERVER STATE
## For each component server return state (on/off)
sub a3_server_state {
    my @output = ();

    foreach my $server ("Conversion", "NLP", "Entity", "Relation", "Export") {
        my $pid = RExtractor::Tools::readFile("./servers/pids/" . lc($server) . ".pid");
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("./servers/pids/" . lc($server) . ".pid");
        if ($pid and (time() - $mtime) < 30 * 60) {
            push(@output, "$server server is ON.\n");
        }
        else {
            push(@output, "$server server is OFF.\n");
        }
    }

    return @output;
}

## B.1 DOCUMENT STATE
## Returns document state number and message.
## Returns submition time (YYYY-MM-DD HH:MM:SS).
sub b1_document_state {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "[ERROR]\nIncorrent document id.\n";
    }

    # Exit if document doesn't exists
    if (!RExtractor::Tools::findDocument($doc_id)) {
        return "[ERROR]\nDocument doesn't exist.\n";
    }

    # Read last file from the log
    my $output = "";
    $output .= "[OK]\n" . RExtractor::Tools::getDocumentStatus($doc_id) . "\n";

    # Print submition time
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("./data/submitted/$doc_id.html");
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
    $output .= "Submition time: " . ($year + 1900) . "-" . sprintf("%02d", ($mon + 1)) . "-" . sprintf("%02d", $mday) . " " . sprintf("%02d", $hour) . ":" . sprintf("%02d", $min) . ":" . sprintf("%02d", $sec) . "\n";

    # Print extraction strategy
    $output .= "Extraction strategy: " . RExtractor::Tools::getDocumentStrategy($doc_id) . "\n";
    return $output;
}

## B.2 SUBMIT NEW DOCUMENT
## Name of the document is in POST-variable doc_id
## Content of the document is in POST-variable doc_content
sub b2_document_submit {
    my ($doc_strategy, $doc_id, $doc_content, $filename) = @_;

    # Check doc_strategy
    if ($doc_strategy !~ /^\w+$/ or not(-r "./strategies/$doc_strategy.xml")) {
        return "[ERROR]\nInvalid extraction strategy.\n"
    }

    # Variant A
    # Content of the document is given in $doc_content
    if ($doc_id and $doc_content and !$filename) {
        if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
            return "[ERROR]\nIncorect document id. See user guide for valid id format.\n";
        }
    
        if (!$doc_id or !$doc_content) {
            return "[ERROR]\nEmpty document id or document concent.\n";
        }
    
        # Fail if ID already exists in the system
        if (RExtractor::Tools::findDocument($doc_id)) {
            return "[ERROR]\nDocument with ID $doc_id already exists.\n";
        }
    
        # Create a file into submitted dir, change permissions
        if (!open(FILE, ">./data/submitted/$doc_id.html")) {
            return "[ERROR]\nCouldn't open file ./data/submitted/$doc_id.html for writing.\n";
        }
        print FILE $doc_content;
        close(FILE);
        chmod(0777, "./data/submitted/$doc_id.html");
    }

    # Variant B
    # Document is given in the file
    if (!$doc_id and !$doc_content and $filename) {
        my $doc_id = $filename;
        $doc_id =~ s/^(?:.*\/)?([^\/]+)\.\w+$/$1/;

        # Fail if ID already exists in the system
        if (RExtractor::Tools::findDocument($doc_id)) {
            return "[ERROR]\nDocument with ID $doc_id already exists.\n";
        }

        # Copy file into submitted dir
        if (system("cp $filename ./data/submitted/$doc_id.html")) {
            return "[ERROR]\tError occured while copying original file into /data/submitted\n";
        }
    }

    # Create log file, set status to 200 - Submited correctly.
    if (!RExtractor::Tools::setDocumentStatus($doc_id, "100 Submited strategy: $doc_strategy.")) {
        return "[ERROR]\nError occured while creating log file '/data/logs/$doc_id.log'\n";
    }
    if (!RExtractor::Tools::setDocumentStatus($doc_id, "200 Submited correctly.")) {
        return "[ERROR]\nError occured while creating log file '/data/logs/$doc_id.log'\n";
    }
    chmod(0777, "./data/logs/$doc_id.log");

    return "[OK]\nSubmitted correctly.\n";
}

## B.3 DOCUMENT DELETE
## Removes document from the system
sub b3_document_delete {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "[ERROR]\nIncorrent document id.\n";
        exit 1;
    }

    # Check state of the document. Don't remove them if any
    # server work with the document.
    my $status = RExtractor::Tools::getDocumentStatus($doc_id);
    if ($status =~ /^(300|400|500|600|700)/) {
        return "[ERROR]\nDocument is processing at this moment.\n";
    }

    # Delete files with given id prefix
    system("rm ./data/converted/$doc_id.* 2>/dev/null");
    system("rm ./data/exported/$doc_id.* 2>/dev/null");
    system("rm ./data/logs/$doc_id.* 2>/dev/null");
    system("rm ./data/submitted/$doc_id.* 2>/dev/null");
    system("rm ./data/treex/$doc_id.* 2>/dev/null");
    system("rm ./data/serialized/$doc_id.* 2>/dev/null");
    system("rm ./servers/tmp/entity/$doc_id.* 2>/dev/null");
    system("rm -rf ./servers/tmp/nlp/$doc_id/ 2>/dev/null");
    system("rm ./servers/tmp/export/$doc_id.* 2>/dev/null");
    system("rm ./servers/tmp/relation/$doc_id.* 2>/dev/null");

    return "[OK]\nDeleted.\n";
}

## C.1 CONTENT HTML
## Returns HTML version of document with chunks annotated by <span> tags
sub c1_content_html {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "[ERROR]\nIncorrent document id.\n";
    }

    # Check state of the document.
    # For unexported documents return message
    my $status = RExtractor::Tools::getDocumentStatus($doc_id);
    if ($status !~ /^(720)/) {
        return "[ERROR]\nDocument is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
    }

    # Load document and return as HTML
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$doc_id.html")) {
        return "[ERROR]\nAn error occured during loading document.\n";
    }

    # Return HTML presentation of the document
    return "[OK]\n" . $Document->getHTML();
}

## C.2 CONTENT CHUNKS
## Return data about specified chunk
sub c2_content_chunks {
    my ($doc_id, $chunk_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "[ERROR]\nIncorrent document id.\n";
    }

    if ($chunk_id !~ /^\d+$/) {
        return "[ERROR]\nIncorrent chunk id.\n";
    }

    # Load Strategy
    my $strategy_id = RExtractor::Tools::getDocumentStrategy($doc_id);
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        return "[ERROR]\nIncorrent strategy id.\n";
    }

    # Load DBE
    my $DBE = new RExtractor::Entities::DBE();
    $DBE->load($Strategy->{entities}{dbe_file});

    # Load document
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$doc_id.html")) {
        return "[ERROR]\nAn error occured during loading document.\n";
    }

    # Find entity
    if (!defined($Document->{chunk2entity}{$chunk_id})) {
        return "[ERROR]\nUnknown entity $chunk_id.\n";
    }

    # Print data
    my $output = "[OK]\n";
    my @entity_ids = keys %{$Document->{chunk2entity}{$chunk_id}};
    foreach my $entity_id (@entity_ids) {
        my @entities = $Document->{description}->findnodes("//entity[\@entity_id = '$entity_id']");
        my @chunks = split(/\s+/, $entities[0]->getAttribute('chunk_ids'));
        my $dbe_id = $entities[0]->getAttribute('dbe_id');
        my $dbe = $DBE->getEntity($dbe_id);
        if (defined($dbe)) {
            $output .= join("\t", ($entity_id, join(", ", @chunks), $dbe->{original_form}, $dbe->{type})) . "\n";
        }
        else {
            $output .= join("\t", ($entity_id, join(", ", @chunks), "", "")) . "\n";
        }
    }

    return $output;
}


## C.3 CONTENT RELATIONS
## Returns extracted relations
sub c3_content_relations {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "[ERROR]\nIncorrent document id.\n";
    }

    # Check state of the document.
    # For unconverted documents return message
    my $status = RExtractor::Tools::getDocumentStatus($doc_id);
    if ($status !~ /^(720)/) {
        return "[ERROR]\nDocument is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
    }

    # Load Strategy
    my $strategy_id = RExtractor::Tools::getDocumentStrategy($doc_id);
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        return "[ERROR]\nIncorrent strategy id.\n";
    }

    # Load DBR
    my $DBR = new RExtractor::Relations::DBR();
    $DBR->load($Strategy->{relation}{dbr_file});
    $DBR->parseQueries();

    # Load document and return as HTML
    my $Document = new RExtractor::Presentation::INTLIB();
    if (!$Document->load("./data/exported/$doc_id.html")) {
        return "[ERROR]\nAn error occured during loading document.\n";
    }

    #Return HTML presentation of the document
    return "[OK]\n" . $Document->getRelations($DBR);
}

## D.1 EXPORT DOCUMENT
## Returns exported document
sub d1_export_document {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "Content-type: text/html\n\n[ERROR]\nIncorrent document id.\n";
    }

    # Fail if ID already exists in the system
    if (!RExtractor::Tools::findDocument($doc_id)) {
        return "Content-type: text/html\n\n[ERROR]\nDocument with ID $doc_id does not exists.\n";
    }

    my $status = RExtractor::Tools::getDocumentStatus($doc_id);
    if ($status !~ /^(720)/) {
        return "Content-type: text/html\n\n[ERROR]\nDocument is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
    }

    # Open document and print it to stdout
    my $output = "";
    open(FILE, "<./data/exported/$doc_id.html");
    while (<FILE>) {
        $output .= $_;
    }
    close(FILE);

    return $output;
}

## D.2 EXPORT DESCRIPTION
## Returns exported document
sub d2_export_description {
    my ($doc_id) = @_;

    # Check params
    if ($doc_id !~ /^[A-Za-z0-9\._\-]+$/) {
        return "Content-type: text/html\n\n[ERROR]\nIncorrent document id.\n";
    }

    # Fail if ID already exists in the system
    if (!RExtractor::Tools::findDocument($doc_id)) {
        return "Content-type: text/html\n\n[ERROR]\nDocument with ID $doc_id does not exists.\n";
    }

    my $status = RExtractor::Tools::getDocumentStatus($doc_id);
    if ($status !~ /^(720)/) {
        return "Content-type: text/html\n\n[ERROR]\nDocument is still processed by RExtractor system. You can browse only fully processed and exported documents.\n";
    }

    # Open document and print it to stdout
    my $output = "";
    $output .= "Content-type: text/xml\n\n";
    open(FILE, "<./data/exported/$doc_id.xml");
    while (<FILE>) {
        $output .= $_;
    }
    close(FILE);

    return $output;
}

## E LIST OF FILES
## Returns list of ids of document which were processed by specified component
sub e_list {
    my ($type, $fromDate, $toDate, $fromDateTime, $toDateTime) = @_;

    # Obtain data
    my @list = ();
    @list = split(/\n/, `grep 200 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-submit");
    @list = split(/\n/, `grep 320 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-convert");
    @list = split(/\n/, `grep 420 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-nlp");
    @list = split(/\n/, `grep 520 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-entity");
    @list = split(/\n/, `grep 620 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-relation");
    @list = split(/\n/, `grep 720 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`) if ($type eq "list-export");

    # If no time constraints are defined, return list
    if ($type =~ /^list-(submit|convert|nlp|entity|relation|export)$/ and
        !defined($fromDate) and !defined($toDate) and
        !defined($fromDateTime) and !defined($toDateTime)) {
        return "[OK]\n" . join("\n", @list);
    }

    # Check params
    if (defined($fromDate) and $fromDate !~ /^\d{4}-\d{2}-\d{2}$/) {
        return "[ERROR]\nIncorrect fromDate. See user guide for valid fromDate format.\n";
    }

    if (defined($toDate) and $toDate !~ /^\d{4}-\d{2}-\d{2}$/) {
        return "[ERROR]\nIncorrect toDate. See user guide for valid toDate format.\n";
    }

    if (defined($fromDateTime) and $fromDateTime !~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
        return "[ERROR]\nIncorrect fromDateTime. See user guide for valid fromDateTime format.\n";
    }

    if (defined($toDateTime) and $toDateTime !~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/) {
        return "[ERROR]\nIncorrect toDateTime. See user guide for valid toDateTime format.\n";
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
        return "[ERROR]\nIncorrect combination of datetime constraints.\n";
    }

    # Convert datetimes to unix timestamp
    my $from = defined($fromDate) ? Date::Parse::str2time("$fromDate 00:00:00") : Date::Parse::str2time($fromDateTime);
    my $to = defined($toDate) ? Date::Parse::str2time("$toDate 23:59:59") : Date::Parse::str2time($toDateTime);

    my $output = "[OK]\n";
    foreach my $id (@list) {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("data/logs/$id.log");

        if ($mtime >= $from and defined($to) and $mtime <= $to) {
            $output .= "$id\n";
            next;
        }

        if ($mtime >= $from and !defined($to)) {
            $output .= "$id\n";
        }
    }

    return $output;
}

## E.7 LIST ALL
## Returns details about each submitted document
sub e7_list_all {
    my ($start, $limit, $order_by, $order_dir) = @_;

    # Check params
    if ($start !~ /^\d+$/) {
        return "[ERROR]\nIncorrent start parameter.\n";
    }

    if ($limit !~ /^\d+$/) {
        return "[ERROR]\nIncorrent limit parameter.\n";
    }

    if ($order_by !~ /^(id|ctime|status)$/) {
        $order_by = "ctime";
    }

    if ($order_dir !~ /^(ASC|DESC)$/) {
        $order_dir = "desc";
    }

    my @list = split(/\n/, `grep -H 200 data/logs/* | cut -f 1 -d ':' | cut -f 3 -d '/' | cut -f 1 -d '.'`);
    my %data = ();
    foreach my $id (@list) {
        my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat("data/submitted/$id.html");
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($mtime);
        my $status = RExtractor::Tools::getDocumentStatus($id);
        $data{$id}{ctime} = $mtime;
        $data{$id}{id} = $id;
        $data{$id}{status} = $status;
        $data{$id}{data} = "$id\t" . ($year + 1900) . "-" . sprintf("%02d", ($mon + 1)) . "-" . sprintf("%02d", $mday) . " " . sprintf("%02d", $hour) . ":" . sprintf("%02d", $min) . ":" . sprintf("%02d", $sec) . "\t$status\n";
    }

    # Sort
    my @sorted_ids = ();
    @sorted_ids = sort {$data{$a}{$order_by} <=> $data{$b}{$order_by}} keys %data if ($order_by =~ /^(ctime)$/);
    @sorted_ids = sort {$data{$a}{$order_by} cmp $data{$b}{$order_by}} keys %data if ($order_by =~ /^(id|status)$/);
    @sorted_ids = reverse @sorted_ids if ($order_dir eq "DESC");

    # Print    
    my $i = 0;
    my $output = "[OK]\n";
    $output .= join("\t", (scalar(keys %data), $start, $limit, $order_by, $order_dir)) . "\n";
    foreach my $id (@sorted_ids) {
        $i++;

        if ($i < $start or $i >= $start + $limit) {
            next;
        }

        $output .= $data{$id}{data};
    }

    return $output;
}

## F.1 BROWSE STRATEGIES
## Returns HTML version of document with chunks annotated by <span> tags
sub f1_strategy_html {
    my ($strategy_id) = @_;

    # Check file
    my $filename = "./strategies/$strategy_id.xml";
    if (not(-r $filename)) {
        return "[ERROR]\nIncorrect strategy ID.\n";
    }

    # Load Strategy
    my $Strategy = new RExtractor::Strategy();
    if (!$Strategy->loadFile("./strategies/$strategy_id.xml")) {
        return "[ERROR]\nIncorrent strategy ID.\n";
    }

    # Return HTML presentation of the document
    my $Format = new RExtractor::Presentation::Strategy();
    return "[OK]\n" . $Format->formatStrategy($Strategy);
}

## G.1 BROWSE DBE
## Returns HTML version of DBE
sub g1_dbe_html {
    my ($dbe_id) = @_;
    print STDERR "API: $dbe_id\n"; # FIXME

    # Check file
    my $filename = "./database/$dbe_id.xml";
    if (not(-r $filename)) {
        return "[ERROR]\nIncorrect DBE ID.\n";
    }

    # Load Strategy
    my $DBE = new RExtractor::Entities::DBE();
    if (!$DBE->load("./database/$dbe_id.xml")) {
        return "[ERROR]\nIncorrent DBE ID.\n";
    }
    $DBE->parse();

    # Return HTML presentation of the document
    my $Format = new RExtractor::Presentation::DBE();
    return "[OK]\n" . $Format->formatDBE($DBE);
}

## H.1 BROWSE DBR
## Returns HTML version of DBR
sub h1_dbr_html {
    my ($dbr_id) = @_;
    print STDERR "API: $dbr_id\n"; # FIXME

    # Check file
    my $filename = "./database/$dbr_id.xml";
    if (not(-r $filename)) {
        return "[ERROR]\nIncorrect DBR ID.\n";
    }

    # Load Strategy
    my $DBR = new RExtractor::Relations::DBR();
    if (!$DBR->load("./database/$dbr_id.xml")) {
        return "[ERROR]\nIncorrent DBR ID.\n";
    }
    $DBR->parseQueries();

    # Return HTML presentation of the document
    my $Format = new RExtractor::Presentation::DBR();
    return "[OK]\n" . $Format->formatDBR($DBR);
}

1;