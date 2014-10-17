#!/usr/bin/perl

use strict;
use warnings;

package RExtractor::Conversion::ZakonyProLidi;

my @ISA = qw(RExtractor::Conversion);

sub new {
    my ($self) = @_;

    $self = {};
    bless $self;
    return $self;
}

sub getDocumentName {
    my ($self, $filename) = @_;

    ## Create new name
    my $new_file = $filename;
    $new_file =~ s/^(.*\/)([^\/]+)$/$2/;
    $new_file =~ s/(.*)\.(.*)/$1/;

    return $new_file;
}

sub loadFile {
    my ($self, $filename) = @_;
    print STDERR "RExtractor::Conversion::loadFile(@_)\n";

    ## Read source HTML
    my @lines = ();
    open (FILE, "<$filename");
    while (<FILE>) {
        chomp($_);
        push(@lines, $_);
    }
    close(FILE);

    return \@lines;
}

sub saveFile {
    my ($self, $data, $filename) = @_;

    open(FILE, ">$filename");
    print FILE $data;
    close(FILE);
}

sub convert {
    my ($self, $ra_html_lines) = @_;

    ##
    ## Conversion to TXT
    ##

    ## Main text extraction (-> @txt)
    my $ra_txt_text = $self->extractText($ra_html_lines);

    ## Novels extraction (-> @txt)
    my $ra_txt_novels = $self->extractNovels($ra_html_lines);

    ## Footnotes extraction (-> @txt)
    my $ra_txt_notes = $self->extractNotes($ra_html_lines);

    ##
    ## Conversion to XML
    ##

    ## Parsing $ra_txt_text to XML
    return $self->txt2xml($ra_html_lines, $ra_txt_text, $ra_txt_novels, $ra_txt_notes);
}

sub txt2xml {
    my ($self, $ra_html_lines, $ra_txt_text, $ra_txt_novels, $ra_txt_notes) = @_;

    ## Create data structure
    my @source_data = ();
    foreach my $line (@{$ra_txt_text}) {
        $line =~ s/&nbsp;/ /g;
        push(@source_data, {text => $line, type => "text"});
    }

    ## Merge paragraphes into one element in the list
    my @paragraphed_data = ();
    my $in_paragraph = 0;
    my $no_paragraphs = 0;
    foreach my $line (@source_data) {
        if ($line->{text} =~ /^(?:§ \d+[a-z]*|Čl. [IVXLCDM]+|[IVXLCDM]+\.(?:\/[a-z]+|[IVXLCDM]+|[A-Z]+|[a-z]+|\s*[a-z]+\))?|[IVXLCDM]+\. [A-Z]+(?:\.[a-z]+)?\) (.*))$/) {
            $in_paragraph = 1;
            push(@paragraphed_data, {type => "section", data => []});
            $no_paragraphs++;
        }
    
        if ($in_paragraph and $line->{text} =~ /^$/) {
            $in_paragraph = 0;
        }
    
        if ($in_paragraph) {
            push(@{$paragraphed_data[$#paragraphed_data]->{data}}, $line);
        }
        else {
            push(@paragraphed_data, $line);
        }
    }

    ## Parsing paragraphs
    foreach my $item (@paragraphed_data) {
        if ($item->{type} eq "section") {
            $item->{structure} = [];
            foreach my $line (@{$item->{data}}) {
                ## Label
                if ($line->{text} =~ /^(?:§\s\d+[a-z]*|Čl. [IVXLCDM]+|[IVXLCDM]+\.(?:\/[a-z]+|[IVXLCDM]+|[A-Z]+|[a-z]+|\s*[a-z]+\))?)$/) {
                    $item->{label} = $line->{text};
                    next;
                }

                ## Special label for court decisions
                if ($line->{text} =~ /^([IVXLCDM]+\. [A-Z](?:\.[a-z]+)?\)) (.*)$/) {
                    $item->{label} = $1;
                    $item->{title} = $2;
                    next;
                }

                ## Title
                if ($line->{text} !~ /^\s/) {
                    $item->{title} = $line->{text};
                    next;
                }
    
                ## Subsections
                if ($line->{text} =~ /^   (\(\d+\)|[a-z]\)|\d+\.) (.*)$/) {
                    push(@{$item->{structure}}, {type => "subsection", label => $1, text => $2, structure => []});
                    next;
                }
                elsif ($line->{text} =~ /^   ([^\s].*)/) {
                    push(@{$item->{structure}}, {type => "text", text => $1});
                    next;
                }
    
                ## Paragraphs
                if ($line->{text} =~ /^      (\(\d+\)|[a-z]\)|\d+\.) (.*)$/) {
                    my $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    #if ($last_subsection->{type} ne "subsection") {
                    #    push(@{$item->{structure}}, {type => "subsection", structure => []});
                    #    $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    #}
                    push(@{$last_subsection->{structure}}, {type => "paragraph", label => $1, text => $2, structure => []});
                    next;
                }
                elsif ($line->{text} =~ /^       ([^\s].*)/) {
                    my $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    #if ($last_subsection->{type} ne "subsection") {
                    #    push(@{$item->{structure}}, {type => "subsection", structure => []});
                    #    $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    #}
                    push(@{$last_subsection->{structure}}, {type => "text", text => $1});
                    next;
                }
    
                ## SUBParagraphs
                if ($line->{text} =~ /^         (\(\d+\)|[a-z]\)|\d+\.) (.*)$/) {
                    my $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    my $last_paragraph = $last_subsection->{structure}[scalar(@{$last_subsection->{structure}}) - 1];
                    push(@{$last_paragraph->{structure}}, {type => "subparagraph", label => $1, text => $2, structure => []});
                    next;
                }
                elsif ($line->{text} =~ /^          ([^\s].*)/) {
                    my $last_subsection = $item->{structure}[scalar(@{$item->{structure}}) - 1];
                    my $last_paragraph = $last_subsection->{structure}[scalar(@{$last_subsection->{structure}}) - 1];
                    push(@{$last_paragraph->{structure}}, {type => "text", text => $1});
                    next;
                }
            }
        }
    }
    
    my @titled_data = ();
    for (my $i = 0; $i < scalar(@paragraphed_data); $i++) {
        my $line = $paragraphed_data[$i];
    
        #print "#$i\t$line->{type}\t$line->{label}\t'$line->{text}'\n";
        
        ## Skusime sa na title vykaslat, ak neexistuje ziaden paragraf (ide asi o notice)
        
        if ($no_paragraphs and
            $i - 1 >= 0 and $paragraphed_data[$i - 1]->{type} eq "text" and $paragraphed_data[$i - 1]->{text} =~ /^$/ and
            $paragraphed_data[$i]->{type} eq "text" and $paragraphed_data[$i]->{text} !~ /^(ČÁST|HLAVA|DÍL|Díl|\s)/ and
            $i + 1 < scalar(@paragraphed_data) and $paragraphed_data[$i + 1]->{type} eq "text" and ($paragraphed_data[$i + 1]->{text} =~ /^$/ or $paragraphed_data[$i + 1]->{text} =~ /^   /) and
            $i + 2 < scalar(@paragraphed_data) and $paragraphed_data[$i + 2]->{type} eq "section")  {
            #print "#NASIEL SOM TITLE ($i)\n";
            #print "\t$i - 1: $paragraphed_data[$i - 1]->{text}"
            $line->{title} = $line->{text};
            $line->{type} = "title";
            $line->{structure} = [];

            ## Osetrujem specialny pripad, ze za title je hned nejaky text na $i+1 riadku...
            if ($paragraphed_data[$i + 1]->{text} =~ /^   /) {
                push(@{$line->{structure}}, $paragraphed_data[$i + 1]);
            }

            my $j = $i + 2;
            while ($j < scalar(@paragraphed_data) and
                   ($paragraphed_data[$j]->{type} eq "section" or
                   ($paragraphed_data[$j]->{type} eq "text" and $paragraphed_data[$j]->{text} =~ /^$/))) {
                push(@{$line->{structure}}, $paragraphed_data[$j]) if ($paragraphed_data[$j]->{type} eq "section");
                $j++;
            }
    
            push(@titled_data, $line);
            $i = $j - 1;
            next;
        }
    
        ## We include empty line only if they is not between sections
        ## or sections and titles
        if ($i - 1 > 0 and $i + 1 < scalar(@paragraphed_data) and
            $paragraphed_data[$i]->{type} eq "text" and $paragraphed_data[$i]->{text} =~ /^$/ and
            $paragraphed_data[$i - 1]->{type} =~ /(section|title)/ and
            $paragraphed_data[$i + 1]->{type} =~ /(section|title)/) {
            next;
        }
    
        push(@titled_data, $line);
    }
    
    my @pododdil_data = ();
    for (my $i = 0; $i < scalar(@titled_data); $i++) {
        my $line = $titled_data[$i];
    
        if ($line->{type} eq "text" and $line->{text} =~ /^(PODODDÍL|Pododdíl)/) {
            $line->{label} = $line->{text};
            $line->{type} = "pododdil";
            $line->{structure} = [];
    
            if ($titled_data[$i + 1]->{type} eq "text" and $titled_data[$i + 1]->{text} =~ /^[^\s]/) {
                #print "#$i: NASIEL SOM NADPIS PODODDILU: '$titled_data[$i + 1]->{text}'\n";
                $line->{title} = $titled_data[$i + 1]->{text};
                $i++;
            }
    
            my $j = $i + 2;
            while ($titled_data[$j]->{type} eq "section" or
                   $titled_data[$j]->{type} eq "title" or
                   ($titled_data[$j]->{type} eq "text" and $titled_data[$j]->{text} =~ /^$/)) {
                push(@{$line->{structure}}, $titled_data[$j]) if ($titled_data[$j]->{type} eq "section" or $titled_data[$j]->{type} eq "title");
                $j++;
            }
    
            push(@pododdil_data, $line);
            $i = $j - 1;
            next;
        }
    
        push(@pododdil_data, $line);
    }
    
    my @oddil_data = ();
    for (my $i = 0; $i < scalar(@pododdil_data); $i++) {
        my $line = $pododdil_data[$i];
    
        if ($line->{type} eq "text" and $line->{text} =~ /^(ODDÍL|Oddíl)/) {
            $line->{label} = $line->{text};
            $line->{type} = "oddil";
            $line->{structure} = [];
    
            if ($pododdil_data[$i + 1]->{type} eq "text" and $pododdil_data[$i + 1]->{text} =~ /^[^\s]/) {
                #print "#$i: NASIEL SOM NADPIS ODDILU: $pododdil_data[$i + 1]->{text}\n";
                $line->{title} = $pododdil_data[$i + 1]->{text};
                $i++;
            }
    
            my $j = $i + 2;
            while ($pododdil_data[$j]->{type} eq "section" or
                   $pododdil_data[$j]->{type} eq "title" or
                   $pododdil_data[$j]->{type} eq "pododdil" or
                   ($pododdil_data[$j]->{type} eq "text" and $pododdil_data[$j]->{text} =~ /^$/)) {
                push(@{$line->{structure}}, $pododdil_data[$j]) if ($pododdil_data[$j]->{type} =~ /(section|title|pododdil)/);
                $j++;
            }
    
            push(@oddil_data, $line);
            $i = $j - 1;
            next;
        }
    
        push(@oddil_data, $line);
    }
    
    
    my @dil_data = ();
    for (my $i = 0; $i < scalar(@oddil_data); $i++) {
        my $line = $oddil_data[$i];
    
        if ($line->{type} eq "text" and $line->{text} =~ /^(DÍL|Díl)/) {
            $line->{label} = $line->{text};
            $line->{type} = "dil";
            $line->{structure} = [];
    
            if ($oddil_data[$i + 1]->{type} eq "text" and $oddil_data[$i + 1]->{text} =~ /^[^\s]/) {
                $line->{title} = $oddil_data[$i + 1]->{text};
                $i++;
            }
    
            my $j = $i + 2;
            while ($j < scalar(@oddil_data) and ($oddil_data[$j]->{type} eq "section" or
                   $oddil_data[$j]->{type} eq "title" or
                   $oddil_data[$j]->{type} eq "pododdil" or
                   $oddil_data[$j]->{type} eq "oddil" or
                   ($oddil_data[$j]->{type} eq "text" and $oddil_data[$j]->{text} =~ /^$/))) {
                push(@{$line->{structure}}, $oddil_data[$j]) if ($oddil_data[$j]->{type} =~ /(section|title|pododdil|oddil)/);
                $j++;
            }
    
            push(@dil_data, $line);
            $i = $j - 1;
            next;
        }
    
        push(@dil_data, $line);
    }
    
    my @headed_data = ();
    for (my $i = 0; $i < scalar(@dil_data); $i++) {
        my $line = $dil_data[$i];
    
        if ($line->{type} eq "text" and $line->{text} =~ /^(HLAVA|Hlava)/) {
            #print "$i: #DIL\n";
    
            $line->{label} = $line->{text};
            $line->{type} = "head";
            $line->{structure} = [];
    
            if ($dil_data[$i + 1]->{type} eq "text" and $dil_data[$i + 1]->{text} =~ /^[^\s]/) {
                $line->{title} = $dil_data[$i + 1]->{text};
                $i++;
            }
    
            my $j = $i + 2;
            #print "#$i: PO HLAVE NASLEDUJE $dil_data[$j]->{type}\n";
            while ($j < scalar(@oddil_data) and ($dil_data[$j]->{type} eq "section" or
                   $dil_data[$j]->{type} eq "title" or
                   $dil_data[$j]->{type} eq "dil" or
                   $dil_data[$j]->{type} eq "pododdil" or
                   $dil_data[$j]->{type} eq "oddil" or
                   ($dil_data[$j]->{type} eq "text" and $dil_data[$j]->{text} =~ /^$/))) {
                push(@{$line->{structure}}, $dil_data[$j]) if ($dil_data[$j]->{type} =~ /(section|title|dil|pododdil|oddil)/);
                $j++;
            }
    
            push(@headed_data, $line);
            $i = $j - 1;
            next;
        }
    
        push(@headed_data, $line);
    }
    
    my @parted_data = ();
    for (my $i = 0; $i < scalar(@headed_data); $i++) {
        my $line = $headed_data[$i];
    
        if ($line->{type} eq "text" and $line->{text} =~ /^(ČÁST|Část)/) {
            $line->{label} = $line->{text};
            $line->{type} = "part";
            $line->{structure} = [];
    
            if ($headed_data[$i + 1]->{type} eq "text" and $headed_data[$i + 1]->{text} =~ /^[^\s]/) {
                $line->{title} = $headed_data[$i + 1]->{text};
                $i++;
            }
    
            my $j = $i + 2;
            while ($j < scalar(@headed_data) and
                   ($headed_data[$j]->{type} eq "section" or
                   $headed_data[$j]->{type} eq "title" or
                   $headed_data[$j]->{type} eq "dil" or
                   $headed_data[$j]->{type} eq "head" or
                   $headed_data[$j]->{type} eq "pododdil" or
                   $headed_data[$j]->{type} eq "oddil" or
                   ($headed_data[$j]->{type} eq "text" and $headed_data[$j]->{text} =~ /^$/))) {
                push(@{$line->{structure}}, $headed_data[$j]) if ($headed_data[$j]->{type} =~ /(section|title|dil|head|oddil|pododdil)/);
                $j++;
            }
    
            push(@parted_data, $line);
            $i = $j - 1;
            next;
        }
    
        push(@parted_data, $line);
    }


    ## 
    ## Metadata z HTML suboru...
    ##

    my $metadata_issued = "";
    my $metadata_valid = "";
    my $metadata_type_of_work = "";
    my $metadata_doc_title = "";
    my $metadata_year = "";
    my $metadata_number = "";
    foreach my $line (@{$ra_html_lines}) {
        chomp($line);
        if ($line =~ /<meta name="description" content="([^"]+)" \/>.*$/) {
            my $description = $1;
            $metadata_type_of_work = $self->getTypeOfWork($description);
            $metadata_doc_title = $self->getDocTitle($description);
            ($metadata_number, $metadata_year) = $self->getNumberYear($description);
        }

        if ($line =~ /Ze dne/) {
            $metadata_issued = $self->getIssuedDate($_);
        }

        if ($line =~ /Účinnost od/) {
            $metadata_valid = $self->getValidDate($_);
        }
    }

    ## 
    ## Footnotes
    ##

    my $id = 1;
    my $foot_notes = "";
    my %foot_notes = ();
    foreach my $line (@{$ra_txt_notes}) {
        chomp($_);
        $_ =~ s/&nbsp;/ /g;
        
        if ($_ =~ s/^([^\)]+\)) (.*)$/\t<foot_note_definition label="$1" id="$id">$2<\/foot_note_definition>/) {
        
        }
        elsif ($_ =~ s/^([^\s]+) (.*)$/\t<foot_note_definition label="$1" id="$id">$2<\/foot_note_definition>/) {
            ## Objavili sme nove poznamky pod ciarou - len hviezdicka            
        }

        $foot_notes{$1} = $id;
        $foot_notes .= "$_\n";
        $id++;
    }

    ##
    ## Novels
    ##

    my $changes = "";
    foreach my $line (@{$ra_txt_novels}) {
        chomp($_);
        $_ =~ s/&nbsp;/ /g;

        if ($_ eq "") {
            next;
        }

        if ($_ =~ /^[^\s]/) {
            if ($changes) {
                $changes .= "\t</section>\n";
            }
            $changes .= "\t<section id=\"$id\">\n";
            $changes .= "\t\t<title>$_</title>\n";
            $id++;
            next;
        }

        if ($_ =~ /^\s+(\d+\.|[a-z]\)) (.*)$/) {
            $changes .= "\t\t<section label=\"$1\" id=\"$id\">\n";
            $changes .= "\t\t\t<text>$2</text>\n";
            $changes .= "\t\t</section>\n";
            $id++;
            next;
        }

        $_ =~ s/^\s*//;
        $changes .= "\t\t<section id=\"$id\">\n";
        $changes .= "\t\t\t<text>$_</text>\n";
        $changes .= "\t\t</section>\n";
        $id++;
    }

    if ($changes) {
        $changes .= "\t</section>\n";
    }

    ## Teraz z toho vygenerujem XML
    my $output = "";
    $output .=  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    $output .=  "<document>\n";
    $output .=  "<metadata>\n";
    $output .=  "\t<docTitle>$metadata_doc_title</docTitle>\n";
    $output .=  "\t<type_of_work>$metadata_type_of_work</type_of_work>\n";
    $output .=  "\t<country_of_issue>cz</country_of_issue>\n";
    $output .=  "\t<number>$metadata_number\/$metadata_year</number>\n" if ($metadata_year and $metadata_number);
    $output .=  "\t<number/>\n" if (!$metadata_year or !$metadata_number);
    $output .=  "\t<language>cz</language>\n";
    $output .=  "\t<issued>$metadata_issued</issued>\n" if ($metadata_issued =~ /\d+-\d+-\d+/);
    $output .=  "\t<valid>$metadata_valid</valid>\n" if ($metadata_valid =~ /\d+-\d+-\d+/);
    $output .=  "\t<issuer/>\n";
    $output .=  "\t<original_format>html</original_format>\n";
    $output .=  "\t<consolidated_by/>\n";
    $output .=  "</metadata>\n";
    $output .=  "<body>\n";

    foreach my $line (@parted_data) {
        $id++;
        $output .= _printXML($line, "", \$id, \%foot_notes);
    }

    $output .=  "</body>\n";

    if ($foot_notes) {
        $output .=  "<foot_notes>\n";
        $output .=  $foot_notes;
        $output .=  "</foot_notes>\n";
    }

    if ($changes) {
        $output .=  "<transitionalProvisions>\n";
        $output .=  $changes;
        $output .=  "</transitionalProvisions>\n";
    }

    $output .=  "</document>\n";

    return $output;    
}

sub extractNotes {
    my ($self, $ra_lines) = @_;

    my $uz_to_zacalo = 0;
    my @output = ();

    foreach my $line (@{$ra_lines}) {
        chomp($line);

        if ($line =~ /RuleNote/) {
            $uz_to_zacalo = 1;
            next;
        }

        if (!$uz_to_zacalo) {
            next;
        }

        if ($line =~ /<\/div>/) {
            last;
        }

        if ($line =~ /L1/) {
            $line =~ s/<[^>]+>//g;
            $line =~ s/(\r|\n)*//g;
            push(@output, $line);
        }
        else {
            $line =~ s/<[^>]+>//g;
            $line =~ s/(\r|\n)*//g;
            $output[$#output] .= " $line";
        }
    }

    return \@output;
}

sub extractNovels {
    my ($self, $ra_lines) = @_;

    my $uz_to_zacalo = 0;
    my @output = ();

    foreach my $line (@{$ra_lines}) {
        chomp($line);

        if ($line =~ /TEMP CC L1/) {
            $uz_to_zacalo = 1;
        }
    
        if (!$uz_to_zacalo) {
            next;
        }
    
        if ($line =~ /^<hr/) {
            last;
        }
    
        if ($line =~ /TEMP CC L1/) {
            $line =~ s/&nbsp;//g;
            $line =~ s/<[^>]+>//g;
            $line =~ s/(\r|\n)*//g;
            push(@output, "\n" . $line);
        }
        else {
            $line =~ s/&nbsp;//g;
            $line =~ s/<[^>]+>//g;
            $line =~ s/(\r|\n)*//g;
            push(@output, "   " . $line);
        }
    }
    
    return \@output;
}

sub saveTxt {
    my ($self, $ra_document, $filename) = @_;

    open (FILE, ">$filename");
    foreach my $line (@{$ra_document}) {
        print FILE $line . "\n";
    }
    close(FILE);

    return 1;
}

sub getDocTitle {
    my ($self, $description) = @_;

    return "$description";
}

sub getValidDate {
    my ($self, $description) = @_;

    if ($description =~ /Účinnost od(?:<[^>]+>)+(\d+)\.(\d+)\.(\d+)/) {
        return "$3-$2-$1";
    }

    return "";
}

sub getIssuedDate {
    my ($self, $description) = @_;

    if ($description =~ /Ze dne(?:<[^>]+>)+(\d+)\.(\d+)\.(\d+)/) {
        return "$3-$2-$1";
    }

    return "";
}

sub getNumberYear {
    my ($self, $description) = @_;

    if ($description =~ /č. (\d+)\/(\d+)/) {
        return ($1, $2);
    }

    return ("", "");
}

## Regularnymi vyrazmi zistime, o aky dokument sa jedna
sub getTypeOfWork {
    my ($self, $description) = @_;

    if ($description =~ /Ústavní zákon, kterým se mění ústavní zákon/ or
        $description =~ /Zákon, kterým se mění (zákon|některé zákony)/ or
        $description =~ /Zákon/ or
        $description =~ /(\w+) zákon/ or
        $description =~ /Ústavn(í|ý) zákon/ or
        $description =~ /Úplné znění zákona/ or
        $description =~ /Dekret/ or
        $description =~ /(Občanský soudní řád|Rozpočtový zákon|Občanský zákoník|Devizový zákon|Ústava|Branný zákon|Dohoda|Dojednanie|Finanční zákon|Hospodářský zákoník|Mierová smluva|Mírová smlouva)/) {
        return "act";
    }

    if ($description =~ /Vqyhl?áška/) {
        return "regulation";
    }

    if ($description =~ /Nařízení/ or
        $description =~ /Naria?denie/ or
        $description =~ /Vládní nařízení/ or
        $description =~ /Vládne nariadenie/) {
        return "decree";
    }
 
    if ($description =~ /Nález/ or
        $description =~ /Sdělení Ústavního soudu/) {
        return "decision";
    }
    
    if ($description =~ /(Sdělení|Oznámení|Oznámenie|Směrnice)/i or
        $description =~ /Rozhodnutí/ or
        $description =~ /Usnesení/ or
        $description =~ /Opatření/ or
        $description =~ /Redakční sdělení/) {
        return "notice";
    }

    return "sourceoflaw";
}

sub extractText {
    my ($self, $ra_lines) = @_;

    my $quoted = 0;
    my $previous_type = "";
    my $previous_class = 0;
    my $previous_indent = 0;
    my $current_indent = 0;
    my $text_began = 0;
    my $quotes = 0;
    my @output = ();

    ## Skusime spojit riadky, ak prvy konci s <br/> a druhy nezacina znackou...
    for (my $i = 0; $i < scalar(@{$ra_lines}) - 1; $i++) {
        if ($$ra_lines[$i] =~ /<br\/>\s*$/) {
            $$ra_lines[$i] =~ s/<br\/>\s*$/ /;
            while ($$ra_lines[$i + 1] !~ /^\s*</) {
                $$ra_lines[$i] .= $$ra_lines[$i + 1];
                splice(@{$ra_lines}, $i + 1, 1);
            }
        }

        if ($$ra_lines[$i] =~ /<\/var>$/) {
            while ($$ra_lines[$i + 1] =~ /^\s+/) {
                $$ra_lines[$i] .= $$ra_lines[$i + 1];
                splice(@{$ra_lines}, $i + 1, 1);
            }
        }

        while ($$ra_lines[$i] =~ /\s+$/ or
               $$ra_lines[$i + 1] =~ /^\s+/) {
            $$ra_lines[$i] .= $$ra_lines[$i + 1];
            splice(@{$ra_lines}, $i + 1, 1);
        }
    }

    foreach my $input_line (@{$ra_lines}) {
        chomp($input_line);

        ## Text begins after the <hr>
        if ($input_line =~ /<hr/) {
            push(@output, "");
            $previous_indent = 0;
            $text_began++;
        }

        ## Skusime ukoncit ked narazime na RuleNote
        if ($input_line =~ /RuleNote/ or
            $input_line =~ /name="prilohy"/ or
            $input_line =~ /TEMP/) {
            last;
        }

        ## Removing HTML tags
        $input_line =~ s/<\/?(var|sup|sub|a|span|img|br)[^>]*>//g;

        ## Pokus s naspisom
        ## Ak este nebola prva ciara, vytlacime vsetko ako nadpis...
        if ($input_line =~ /<p.*class="L1 ">(.*)<\/p>/ and
            $text_began == 0) {
            push(@output, $1);
            next;
        }

        ## Blockguotes
        if ($input_line =~ /<blockquote/) {
            $input_line =~ s/<blockquote[^>]*>//;
            $quoted = 1;
        }

        if ($input_line =~ /<\/blockquote>/) {
            $quoted = 0;
        }

        if ($quoted) {
            $input_line =~ s/<\/?(p|var|sup|sub|a|span|img|br)[^>]*>//g;
            $output[$#output] .= " $input_line";
            next;
        }

        my $class = "";
        my $text = "";
        if ($input_line =~ /<(?:p|h\d+).*class="(.*)">(.*)<\/(?:p|h\d+)>/) {
            $class = $1;
            $text = $2;
            $text =~ s/^(\s*)(\(?(?:\d+|[a-z])\.?\)?)\s+(.*)$/$1$2 $3/;
            $text =~ s/&nbsp;/ /g;
        }

        if (!$class) {
            next;
        }

        my $current_class = 0;
        if ($class =~ /L(\d+)/) {
            $current_class = $1;
        }

        ## When should I print blank \n
        if ($class =~ /(?:HLAVA|CAST|PARA|CLANEK|KAPITOLA|DIL)/) {
            push(@output, "");
            push(@output, "$text");

            $previous_class = 0;
            $previous_indent = 0;
            $current_indent = 3;
            $previous_type = "part";

            next;
        }
    
        ## Titles have no indentation
        if ($class =~ /NADPIS/) {
            push(@output, "") if ($previous_type ne "part");
            push(@output, "$text");

            $previous_class = 0;
            $previous_indent = 0;
            $current_indent = 3;
            $previous_type = "title";

            next;
        }
    
        if ($class =~ /GO/) {
            if ($previous_class == 0) {
                $previous_class = $current_class;
                $current_indent = 3;
                $previous_indent = $current_indent;
            }
            else {
                if ($previous_class < $current_class) {
                    $current_indent += 3 * ($current_class - $previous_class);
                    $previous_indent = $current_indent;
                    $previous_class = $current_class;
                }
                elsif ($previous_class > $current_class) {
                    $current_indent -= 3 * ($previous_class - $current_class);
                    $previous_indent = $current_indent;
                    $previous_class = $current_class;
                }
            }
            $previous_type = "";
        }

        if ($class =~ /^\s*L\d+\s*$/ and ($previous_indent or $previous_type eq "cont")) {
            $output[$#output] .= " $text";
            $previous_type = "cont";
            next;
        }

        push(@output, substr("                           ", 0, $current_indent) . "$text");
    }

    return @output;
}

sub _printXML {
    my ($element, $prefix, $id, $foot_notes) = @_;
    my $output = "";

    ## Unparsed lines
    if (!defined($element->{type})) {
        return;
    }

    ## Empty lines
    if ($element->{type} eq "text" and $element->{text} =~ /^$/) {
        return;
    }

    ## Type text
    if ($element->{type} eq "text" and $element->{text} !~ /^$/) {
        foreach my $foot_note (keys %{$foot_notes}) {
            my $foot_note_regexp = $foot_note;
            $foot_note_regexp =~ s/([\*\)])/\\$1/g;
            $element->{text} =~ s/([^\d])($foot_note_regexp)([^\w\*])/$1<foot_note_reference foot_note_id="$foot_notes->{$foot_note}">$2<\/foot_note_reference>$3/;
        }

        $output .= $prefix . "<text>$element->{text}</text>\n";
        return $output;
    }

    ## Here elements name are modyfied according to XML Schema
    my $element_name = $element->{type};
    $element_name = $element_name eq "dil" ? "crossheading" : $element_name;
    $element_name = $element_name eq "oddil" ? "crossheading" : $element_name;
    $element_name = $element_name eq "pododdil" ? "crossheading" : $element_name;
    $element_name = $element_name eq "title" ? "crossheading" : $element_name;
    $element_name = $element_name eq "paragraph" ? "section" : $element_name;
    $element_name = $element_name eq "subparagraph" ? "section" : $element_name;
    $element_name = $element_name eq "subsection" ? "section" : $element_name;

    ## Other (hierarchical tags)
    $$id++;
    $output .= $prefix . "<$element_name id=\"$$id\"";
    $output .= " label=\"$element->{label}\"" if (defined($element->{label}));
    $output .= ">\n" ;
    $output .= $prefix . "\t<title>$element->{title}</title>\n" if ($element->{title});
    $output .= $prefix . "\t<text>$element->{text}</text>\n" if ($element->{text} and scalar(@{$element->{structure}}));
    foreach my $_element (@{$element->{structure}}) {
        print STDERR "\n\nStruktura elementu $element->{label}\n";
        foreach my $key (keys %{$_element}) {
            print STDERR "\t$key = $_element->{$key}\n";
        }

        $output .= _printXML($_element, $prefix . "\t", $id, $foot_notes);
    }
    if (!scalar(@{$element->{structure}}) and defined($element->{text})) {
        #$element->{text} =~ s/<[^>]+>//g;
        foreach my $foot_note (keys %{$foot_notes}) {
            my $foot_note_regexp = $foot_note;
            $foot_note_regexp =~ s/([\*\)])/\\$1/g;
            $element->{text} =~ s/([^\d])($foot_note_regexp)([^\w\*])/$1<foot_note_reference foot_note_id="$foot_notes->{$foot_note}">$2<\/foot_note_reference>$3/;
        }
        $output .= $prefix . "\t<text>$element->{text}</text>\n";
    }

    $output .= $prefix . "</$element_name>\n";
    return $output;
}

1;
