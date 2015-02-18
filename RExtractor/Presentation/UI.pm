#!/usr/bin/perl

use strict;
use warnings;

use RExtractor::Tools;

package RExtractor::Presentation::UI;

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub getHTMLHead {
    my ($self) = @_;

    my $output = "";
    $output .= "<!DOCTYPE html>\n";
    $output .= "<html lang='cs'>\n";
    $output .= "<head>\n";
    $output .= "\t<meta http-equiv='content-type' content='text/html; charset=utf-8'/>\n";
    $output .= "\t<title>RExtractor UI</title>\n\n";
    $output .= "\t<link rel=\"shortcut icon\" href=\"images/favicon.png\">\n";

    # CSS
    $output .= "\t<link rel='stylesheet' type='text/css' href='styles/styles.css'/>\n";

    # JS
    $output .= "\t<script type='text/javascript' src='javascript/jquery-1.7.1.min.js'></script>\n";
    $output .= "\t<script type='text/javascript' src='javascript/applets.js'></script>\n";

    $output .= "</head>\n\n";
    $output .= "<body>\n";

    return $output;
}

sub getHeader {
    my ($self) = @_;

    my $output .= "\n";
    $output .= "<!-- Logo & menu -->\n";
    $output .= "<div id='header'>\n";
    $output .= "\t<div id='header_content'>\n";
    $output .= "\t\t<img src='images/logo.png' class='header-logo'>\n";
    $output .= "\t</div>";
    $output .= "</div>\n\n";

    return $output;
}

sub getText {
    my ($self, $text_id) = @_;

    my $text = `cat ./texts/$text_id.html`;

    my $output .= "\n";
    $output .= "<div class='box'>";
    $output .= $text;
    $output .= "</div>";

    return $output;
}

sub getMenu {
    my ($self) = @_;

    my $output .= "\n";
    $output .= "<!-- Menu -->\n\n";
    $output .= "<div class='box'>";
    $output .= "<h2>Menu</h2>";
    $output .= "<ul>";
    $output .= "<li><a href='javascript:run_text(\"welcome\");'>Home</a>";
    $output .= "<li><a href='javascript:run_text(\"about\");'>Learn more</a>";
    $output .= "<li><a href='javascript:run_submit()'>Submit new job</a>";
    $output .= "<li><a href='javascript:run_list();'>Browse submitted jobs</a>";
    $output .= "<li><a href='javascript:run_sb();'>Browse strategies</a>";
    $output .= "<li><a href='javascript:run_dbe();'>Browse entities</a>";
    $output .= "<li><a href='javascript:run_dbr();'>Browse relations</a>";
    #$output .= "<li><a href='javascript:run_text(\"contact\");'>Contact</a>";
    $output .= "</ul>";
    $output .= "</div>";
}

sub appletServerStatus {
    my ($self) = @_;

    my $output = "";
    $output .= "<div class='box' id='applet_server_status'>";
    $output .= "<h2>Server status</h2>";
    $output .= "<div class='loading'></div>";
    $output .= "<div class='data'></div>";
    $output .= "</div>";
}

sub appletList {
    my ($self, $status) = @_;

    my $output = "";
    $output .= "<div class='box' id='applet_server_status' style='width: 250px'>";
    $output .= "<h2>Server status</h2>";
    $output .= "<div class='loading'></div>";
    $output .= "<div class='data'></div>";
    $output .= "</div>";
}

sub getDaemonStatus {
    my ($self) = @_;
    my @servers = ("conversion", "nlp");
    
    # Obtain data
    my %statuses = ();
    foreach my $server (@servers) {
        $statuses{$server} = 0;

        my $pid = RExtractor::Tools::readFile("./servers/pids/$server.pid");
        if ($pid and `ps -A | grep $pid | wc -l` =~ /1/) {
            $statuses{$server} = 1
        }
    }

    # Format data    
    my $output .= "<div class='box'>";
    $output .= "<h2>Server status</h2>";
    $output .= "<table>";
    foreach my $server (@servers) {
        $output .= "<tr>";
        if ($statuses{$server}) {
            $output .= "<td><img src='images/green.png'></td><td>$server server is up</td>";
        }
        else {
            $output .= "<td><img src='images/red.png'></td><td>$server server is down</td>";
        }
        $output .= "</tr>";
    }
    $output .= "</table>";
    $output .= "</div>";

    return $output;
}

sub getFooter {
    my ($self) = @_;

    my $output = "";
    $output .= "<div id='footer'>";
    #$output .= "<p>&copy; 2015 Vincent Kríž</p>";
    $output .= "</div>";

    return $output;
}

sub getHTMLFoot {
    my ($self) = @_;

    my $output = "";
    $output .= "</body>\n";
    $output .= "</html>\n";

    return $output;
}

1;