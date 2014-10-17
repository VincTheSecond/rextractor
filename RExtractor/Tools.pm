#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Tools;

sub readFile {
    my ($filename) = @_;

    if (not(-f $filename)) {
        return undef;
    }

    my $output = "";
    open(FILE, "<$filename");
    while (<FILE>) {
        $output .= $_;
    }
    close(FILE);

    return $output;
}

sub writeFile {
    my ($filename, $data) = @_;

    open(FILE, ">$filename");
    print FILE $data;
    close(FILE);

    return 1;
}

sub deleteFile {
    my ($filename) = @_;

    unlink($filename);

    return 1;
}

sub findDocument {
    my ($document_id) = @_;

    if (-f "./data/logs/$document_id.log") {
        return 1;
    }

    return 0;
}

sub getDocumentStatus {
    my ($document_id) = @_;

    my $data = `tail -n 1 ./data/logs/$document_id.log 2>/dev/null`;
    chomp($data);

    return $data;
}

sub setDocumentStatus {
    my ($document_id, $status) = @_;

    if (!open(FILE, ">>./data/logs/$document_id.log")) {
        return 0;
    }

    print FILE "$status\n";
    close(FILE);

    return 1;
}

##
## DEBUG PROCEDURES
##

sub info {
    my ($file_handler, $message) = @_;

    my ($logsec, $logmin, $loghour, $logmday, $logmon, $logyear, $logwday, $logyday, $logisdst) = localtime(time);
    my $logtimestamp = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $logyear + 1900, $logmon + 1, $logmday, $loghour, $logmin, $logsec);

    print $file_handler  "$logtimestamp\t[INFO]\t$message\n";
    $file_handler->autoflush();
}

sub warning {
    my ($file_handler, $message) = @_;

    my ($logsec, $logmin, $loghour, $logmday, $logmon, $logyear, $logwday, $logyday, $logisdst) = localtime(time);
    my $logtimestamp = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $logyear + 1900, $logmon + 1, $logmday, $loghour, $logmin, $logsec);

    print $file_handler  "$logtimestamp\t[WARN]\t$message\n";
    $file_handler->autoflush();
}

sub error {
    my ($file_handler, $message) = @_;

    my ($logsec, $logmin, $loghour, $logmday, $logmon, $logyear, $logwday, $logyday, $logisdst) = localtime(time);
    my $logtimestamp = sprintf("%4d-%02d-%02d %02d:%02d:%02d", $logyear + 1900, $logmon + 1, $logmday, $loghour, $logmin, $logsec);

    print $file_handler  "$logtimestamp\t[ERROR]\t$message\n";
    $file_handler->autoflush();
}


1;