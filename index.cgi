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
use RExtractor::API;
use RExtractor::Document;
use RExtractor::Entities::DBE;
use RExtractor::Relations::DBR;

## -------------------------------------------------------------------------------
## HTTP INTERFACE
## -------------------------------------------------------------------------------

## Parse params from URL
my $COMMAND = $Source->url_param('command') ? $Source->url_param('command') : "";

## A.3 SERVER STATE
## For each component server return state (on/off)
if ($COMMAND eq "server-state") {
    print "Content-type: text/html\n\n";
    print "[OK]\n";

    my @output = RExtractor::API::a3_server_state();
    print join("", @output);

    exit 0;
}

## B.1 DOCUMENT STATE
## Returns document state number and message.
## Returns submition time (YYYY-MM-DD HH:MM:SS).
if ($COMMAND eq "document-state") {
    print "Content-type: text/html\n\n";

    # Load params & call function
    my $doc_id = $Source->url_param("doc_id");
    print RExtractor::API::b1_document_state($doc_id);

    exit 0;
}

## B.2 SUBMIT NEW DOCUMENT
## Name of the document is in POST-variable doc_id
## Content of the document is in POST-variable doc_content
if ($COMMAND eq "document-submit") {
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->param("doc_id");
    my $doc_content = $Source->param("doc_content");
    my $doc_strategy = $Source->param("doc_strategy");
    print RExtractor::API::b2_document_submit($doc_strategy, $doc_id, $doc_content, undef);

    exit 0;
}

## B.3 DOCUMENT DELETE
## Removes document from the system
if ($COMMAND eq "document-delete") {
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->url_param("doc_id");
    print RExtractor::API::b3_document_delete($doc_id);

    exit 0;
}

## C.1 CONTENT HTML
## Returns HTML version of document with chunks annotated by <span> tags
if ($COMMAND eq "content-html") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->url_param("doc_id");
    print RExtractor::API::c1_content_html($doc_id);

    exit 0;
}

## C.2 CONTENT CHUNKS
## Return data about specified chunk
if ($COMMAND eq "content-chunks") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->url_param("doc_id");
    my $chunk_id = $Source->url_param("chunk_id");
    print RExtractor::API::c2_content_chunks($doc_id, $chunk_id);

    exit 0;
}

## C.3 CONTENT RELATIONS
## Returns extracted relations
if ($COMMAND eq "content-relations") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->url_param("doc_id");
    print RExtractor::API::c3_content_relations($doc_id);

    exit 0;
}

## D.1 EXPORT DOCUMENT
## Returns exported document
if ($COMMAND eq "export-document") {
    print "Content-type: text/html\n\n";

    # Load params
    my $doc_id = $Source->url_param("doc_id");
    print RExtractor::API::d1_export_document($doc_id);

    exit 0;
}

## D.2 EXPORT DESCRIPTION
## Returns exported document
if ($COMMAND eq "export-description") {
    # Load params
    my $doc_id = $Source->param("doc_id");
    print RExtractor::API::d2_export_description($doc_id);

    exit 0;
}

## E LIST OF FILES
## Returns list of ids of document which were processed by specified component
if ($COMMAND =~ /^list-(submit|convert|nlp|entity|relation|export)$/) {
    print "Content-type: text/html\n\n";

    my $type = $COMMAND;
    my $fromDate = $Source->param("fromDate");
    my $toDate = $Source->param("toDate");
    my $fromDateTime = $Source->param("fromDateTime");
    my $toDateTime = $Source->param("toDateTime");

    print RExtractor::API::e_list($type, $fromDate, $toDate, $fromDateTime, $toDateTime);
    exit 0;
}

## E.7 LIST ALL
## Returns details about each submitted document
if ($COMMAND eq "list-all") {
    print "Content-type: text/html\n\n";

    # Load params
    my $start = $Source->url_param("start") ? $Source->url_param("start") : 0;
    my $limit = $Source->url_param("limit") ? $Source->url_param("limit") : 10;
    my $order_by = $Source->url_param("order_by") ? $Source->url_param("order_by") : "ctime";
    my $order_dir = $Source->url_param("order_dir") ? $Source->url_param("order_dir") : "DESC";

    print RExtractor::API::e7_list_all($start, $limit, $order_by, $order_dir);
    exit 0;
}

## F.1 BROWSING STRATEGIES
## Returns HTML presentation of specified strategy
if ($COMMAND eq "strategy-html") {
    print "Content-type: text/html\n\n";

    # Load params
    my $strategy_id = $Source->param("strategy_id") ? $Source->param("strategy_id") : "";
    print RExtractor::API::f1_strategy_html($strategy_id);
    exit 0;
}

## G.1 BROWSING DBE
## Returns HTML presentation of specified DBE
if ($COMMAND eq "dbe-html") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    print STDERR "index\n"; # FIXME
    my $dbe_id = $Source->param("dbe_id") ? $Source->param("dbe_id") : "";
    print RExtractor::API::g1_dbe_html($dbe_id);
    exit 0;
}

## G.1 BROWSING DBR
## Returns HTML presentation of specified DBR
if ($COMMAND eq "dbr-html") {
    binmode(STDOUT, ":encoding(utf8)");
    print "Content-type: text/html\n\n";

    # Load params
    print STDERR "index\n"; # FIXME
    my $dbr_id = $Source->param("dbr_id") ? $Source->param("dbr_id") : "";
    print RExtractor::API::h1_dbr_html($dbr_id);
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

