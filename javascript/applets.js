/**
 * (c) 2014, Vincent Kriz, kriz@ufal.mff.cuni.cz
 * This script implements RExtractor web interface
 */

// Global variabiles
var id = "";
var content = "";
var message = "";
var highlight = "";
var box = undefined;
var timeout = undefined;

// Start with welcome screen
jQuery('body').ready(function() {
    applet_server_status();
    applet_text_box('welcome');
});

// Functions in menu
function run_text(text_id) {
    clear_main_column();
    applet_text_box(text_id);
}

function run_list(id_to_highlight, refresh) {
    clear_main_column();
    applet_list(id_to_highlight, refresh);
}

function run_submit() {
    clear_main_column();
    applet_submit();
}

function run_document(id) {
    clear_main_column();
    applet_document(id);
}

/**
 * APPLETS
 */
function applet_server_status() {
    jQuery.ajax({
        url: "./index.cgi?command=server-state",
        success: function(data) {
            var servers = data.split('\n');

            // Format HTML output
            var output = "";
            output += "<table>";
            for (var i = 0; i < servers.length; i++) {
                if (!servers[i].match(/(ON|OFF)/)) {
                    continue;
                }

                if (servers[i].match(/ON/)) {
                    output += "<tr><td><img src='images/green.png'></td><td>" + servers[i] + "</td></tr>";
                }
                else {
                    output += "<tr><td><img src='images/red.png'></td><td>" + servers[i] + "</td></tr>";
                }
            }
            output += "</table>";

            // Hide loading and show table
            jQuery('#applet_server_status .loading').slideUp();
            jQuery('#applet_server_status .data').html(output);
            jQuery('#applet_server_status .data').slideDown();
        },
        error: function() {
            jQuery('#applet_server_status').html("<p>Couldn't retrieve server status</p>");
        }
    });
    setTimeout('applet_server_status()', 5000);
}

function applet_text_box(text_id) {
    // Clear timeout
    clearTimeout(timeout);

    jQuery.ajax({
        url: "./texts/" + text_id + ".html",
        success: function(data) {
            // Format HTML output
            var output = "";
            output += "<div class='box'>";
            output += data;
            output += "</div>";

            // Show data
            jQuery('#main-column').append(output);
            jQuery('#main-column').find('.box').each(function() {
                jQuery(this).slideDown();
            });
        },
        error: function() {
            jQuery('#applet_server_status').html("<p>Couldn't retrieve text.</p>");
        }
    });
}

function applet_list(id_to_highlight, refresh) {
    // Clear timeout
    clearTimeout(timeout);

    // Clear message
    message = "";

    var output = "";

    if (!refresh) {
        output += "<div class='box'>";
        output += "<h2>List of submitted documents</h2>"
        output += "<div class='loading'></div>";
        output += "<div class='message'>" + message + "</div>";
        output += "<div class='data'></div>";
        output += "</div>";

        // Hide loading and show table
        box = jQuery('#main-column').append(output);
        jQuery('#main-column').find('.box').each(function() {
            jQuery(this).slideDown();
        });
    }

    jQuery.ajax({
        url: "./index.cgi?command=list-all",
        success: function(data) {
            var jobs = data.split('\n');

            // Format HTML output
            var output = "";
            output += "<table class='list'>";
            output += "<tr><th>Document</th><th>Submition time</th><th colspan=3>State</th></tr>";
            for (var i = 0; i < jobs.length; i++) {
                if (!jobs[i].match(/./)) {
                    continue;
                }

                var fields = jobs[i].split(/\t/);

                // Highlight selected document
                if (id_to_highlight && jobs[i].match(new RegExp("^" + id_to_highlight + "\t"))) {
                    output += "<tr class='highlight' id='document_" + fields[0] + "'>";
                }
                else {
                    output += "<tr id='document_" + fields[0] + "'>";
                }

                // Process icon
                var icon = "";
                if (fields[2].match(/[34567]00/)) {
                    icon = "images/greening.gif";
                }
                if (fields[2].match(/\d10/)) {
                    icon = "images/red.png";
                }
                if (fields[2].match(/(200|[34567]20)/)) {
                    icon = "images/green.png";
                }

                // Progress bar
                var state = fields[2];
                var percent = "";
                percent = state.replace(/^(\d).*$/, "$1");
                percent -= 1;
                percent = (100 / 6) * percent;
                var color = state.match(/\d10/) ? "red" : "green";
                var progress_bar = "<div class='state-bar-mini'><div class='state-bar-content-mini' style='width: " + percent + "%; background: " + color + "'></div></div>";

                // Fill table
                output += "<td>" + fields[0] + "</td>";
                output += "<td>" + fields[1] + "</td>";
                output += "<td><img src='" + icon + "'></td>";
                output += "<td>" + progress_bar + "</td>";
                output += "<td>" + fields[2] + "</td>";
            }
            output += "</table>";

            if (!refresh) {
                box.find('.loading').slideUp();
                box.find('.data').html(output);
                box.find('.data').slideDown();
            }
            else {
                box.find('.data').html(output);
            }

            box.find('.data').find('tr').each(function() {
                jQuery(this).click(function() {
                    var id = jQuery(this).attr('id').replace(/document_/, "");
                    run_document(id);
                })
            })
        },
        error: function() {
            jQuery('#applet_server_status').html("<p>Couldn't retrieve server status</p>");
        }
    });

    timeout = setTimeout("applet_list('" + id_to_highlight + "', 1)", 10000);
}

function applet_submit() {
    // Clear timeout
    clearTimeout(timeout);

    // Form
    var form = "";
    form += "<p>Job identification:</p>";
    form += "<input type='text' id='new_submit_id' value='" + id + "'>";
    form += "<p>Input unstructured text:</p>";
    form += "<textarea id='new_submit_content'>" + content + "</textarea><br>";
    form += "<input type='button' value='Submit new job!' onClick='applet_submit_click()'>";

    var output = "";
    output += "<div class='box'>";
    output += "<h2>Submit new job</h2>"
    output += "<div class='loading'></div>";
    output += "<div class='message'>" + message + "</div>";
    output += "<div class='form'>";
    output += form;
    output += "</div>";
    output += "<div class='data'></div>";
    output += "</div>";

    // Hide loading and show table
    box = jQuery('#main-column').append(output);
    jQuery('#main-column').find('.box').each(function() {
        jQuery(this).slideDown();
    });
    box.find('.loading').slideUp();
}

function applet_submit_click() {
    // Hide form, show loading
    jQuery('.form').slideUp();
    box.find('.loading').slideDown();

    // Read data
    id = jQuery('#new_submit_id').val();
    content = jQuery('#new_submit_content').val();

    // Check data
    if (!id.match(/^\w+$/)) {
        message = "<p class='error'>Incorrect job identifier.";
        run_submit();
    }

    if (!content.match(/^\w+$/)) {
        message = "<p class='error'>Incorrect content. Please, insert an unstructured text.</p>";
        run_submit();
    }

    // Everything OK, submit query on the server
    jQuery.ajax({
        url: "./index.cgi?command=document-submit",
        data: {
          doc_id: id,
          doc_content: content
        },
        success: function(data) {
            if (data.match(/OK/)) {
                message = "<p class='ok'>Job submitted correctly.</p>"
                run_list(id);
            }
            else {
                message = "<p class='error'>" + data + "</p>";
                run_submit();
            }
        },
        error: function() {
            alert("Chyba");
        }
    });
}

function applet_document(id) {
    var output = "";
    output += "<div class='box'>";
    output += "<h2>Document " + id + " </h2>"
    output += "<div class='state'></div>";
    output += "<div class='content'></div>";
    output += "<div class='relations'></div>";
    output += "</div>";

    // Hide loading and show table
    var box = jQuery('#main-column').append(output);
    jQuery('#main-column').find('.box').each(function() {
        jQuery(this).slideDown();
    });

    // Document status
    get_document_state(id, box);
    get_document_content(id, box);
    get_document_relations(id, box);
}

function clear_main_column() {
    jQuery('#main-column').find('.box').each(function() {
        jQuery(this).fadeOut();
        jQuery(this).remove();
    });
}

function get_document_relations(doc_id, box) {
    jQuery.ajax({
        url: "./index.cgi?command=content-relations&doc_id=" + doc_id,
        success: function(data) {
            var output = "";
            output += "<h3>Relations</h3>";

            var lines = data.split(/\n/);
            for (var i = 0; i < lines.length; i++) {
                var fields = lines[i].split(/\t/);
                if (fields.length == 10) {
                    output += "<tr>";
                    output += "<td>" + fields[0] + "</td>";
                    output += "<td>" + fields[1] + "</td>";
                    output += "<td>" + fields[2] + "</td>";
                    output += "<td>" + fields[3] + "</td>";
                    output += "<td>" + fields[4] + "</td>";
                    output += "<td>" + fields[5] + "</td>";
                    output += "<td>" + fields[6] + "</td>";
                    output += "<td>" + fields[7] + "</td>";
                    output += "<td>" + fields[8] + "</td>";
                    output += "<td>" + fields[9] + "</td>";
                    output += "</tr>";
                }
                if (lines[i].match(/<h4>/)) {
                    output += "</table>";
                    output += lines[i];
                }
                if (lines[i].match(/<i>/)) {
                    output += lines[i];
                    output += "<table class='list'>";
                    output += "<tr>";
                    output += "<th>Relation</th>";
                    output += "<th colspan=3>Subject</th>";
                    output += "<th colspan=3>Predicate</th>";
                    output += "<th colspan=3>Object</th>";
                    output += "</tr>";
                }
            }

            output += "</table>";
            box.find(".relations").html(output);

            // Highlighting relations
            //jQuery('.chunk').click(function() {
            //    chunk_id = jQuery(this).attr('id');
            //    highlight_chunk(doc_id, chunk_id, box);
            //});
        },
        error: function() {
            box.find(".relations").html("<h3>Relations</h3><div class='document'><p>Couldn't retrieve relations.</p></div>");
        }
    });
}

function get_document_content(doc_id, box) {
    box.find(".content").html("<h3>Document</h3><div class='loading'></div>");

    jQuery.ajax({
        url: "./index.cgi?command=content-html&doc_id=" + doc_id,
        success: function(data) {
            box.find(".content").html("<h3>Document</h3><div class='document'>" + data + "</div><div class='entities'></div><div style='clear: both'></div>");
            jQuery('.chunk').click(function() {
                chunk_id = jQuery(this).attr('id');
                highlight_chunk(doc_id, chunk_id, box);
            });
        },
        error: function() {
            box.find(".content").html("<h3>Document</h3><div class='document'><p>Couldn't retrieve document.</p></div><div class='entities'></div><div style='clear: both'></div>");
        }
    });
}

function highlight_chunk(doc_id, chunk_id, box) {
    box.find(".entities").slideUp();
    box.find(".entities").html("<div class='loading'></div>");
    box.find(".entities").slideDown();

    jQuery.ajax({
        url: "./index.cgi?command=content-chunks&doc_id=" + doc_id + "&chunk_id=" + chunk_id,
        success: function(data) {
            // Fill entities box
            var output = "";
            var entities = data.split("\n");
            for (var i = 0; i < entities.length - 1; i++) {
                var fields = entities[i].split(/\t/);
                output += "<div class='highlighted_entity' id='" + i + "'>";
                output += "Entity: " + fields[0] + "<br>";
                output += "Chunks: " + fields[1] + "<br>";
                output += "<b>" + fields[2] + "</b><br>";
                output += "<i>" + fields[3] + "</i>";
                output += "</div>";
            }

            box.find(".entities").html("<h2>Chunk details</h2><p>" + output + "</p>");

            // Highlight entity
            jQuery('.highlighted_entity').hover(function() {
                var line = jQuery(this).attr('id');
                var fields = entities[line].split(/\t/);
                var chunks = fields[1].split(/, /);

                for (var i = 0; i < chunks.length; i++) {
                    jQuery('#' + chunks[i]).addClass("highlighted_chunk");
                }
            },
            function() {
                var line = jQuery(this).attr('id');
                var fields = entities[line].split(/\t/);
                var chunks = fields[1].split(/, /);

                for (var i = 0; i < chunks.length; i++) {
                    jQuery('#' + chunks[i]).removeClass("highlighted_chunk");
                }
            });
        },
        error: function() {
            return "";
        }
    });

}

function get_document_state(id, box) {
    clearTimeout(timeout);

    if (!box) {
        box = jQuery('#main-column .box');
    }

    jQuery.ajax({
        url: "./index.cgi?command=document-state&doc_id=" + id,
        success: function(data) {
            if (data.match(/ERROR/)) {
                box.find(".state").html("<p class='error'>Couldn't retrieve document state.</p>");
                return;
            }

            var icon = "";
            var text = "";
            if (data.match(/[34567]00/)) {
                icon = "images/greening.gif";
                text = "At this moment, document is processing by one of the RExtractor components.";
            }
            if (data.match(/\d10/)) {
                icon = "images/red.png";
                text = "An error occured during document processing. Job was cancelled."
            }
            if (data.match(/(200|[3456]20)/)) {
                icon = "images/green.png";
                text = "Document is waiting for another component.";
            }
            if (data.match(/(720)/)) {
                icon = "images/green.png";
                text = "Document processing is complete.";
            }

            var lines = data.split("\n");
            var submition_time = lines[2];
            submition_time = submition_time.replace(/Submition time:/, "");

            var state = lines[1];
            state = state.replace(/\[OK\] /, "");

            var percent = "";
            percent = state.replace(/^(\d).*$/, "$1");
            percent -= 1;
            percent = (100 / 6) * percent;
            var color = state.match(/\d10/) ? "red" : "green";
            var progress_bar = "<div class='state-bar'><div class='state-bar-content' style='width: " + percent + "%; background: " + color + "'></div></div>";

            var output = "";
            output += "<h3>Current status</h3>";
            output += "<table><tr><td><img src='" + icon + "'></td><td>" + text + "</td></tr></table>";
            output += "<h3>Progress bar</h3>";
            output += progress_bar;
            output += "<h3>Details</h3>";
            output += "<table class='list'>";
            output += "<tr><th>Document</th><th>Submition time</th><th>State</th><th>Actions</th></tr>";
            output += "<tr><td>" + id + "</td><td>" + submition_time + "</td><td>" + state + "</td><td><span class='delete'>Delete document</span></td></tr>";
            output += "</table>";

            box.find(".state").html(output);

            jQuery('.delete').click(function() {
                if (!confirm("Document will be permanently deleted from the RExtractor system. Do you want to continue?")) {
                    return;
                }

                jQuery.ajax({
                    url: "./index.cgi?command=document-delete&doc_id=" + id,
                    success: function(data) {
                        if (data.match(/\[OK\]/)) {
                            message = "<p class='ok'>Document " + id + " was deleted from the RExtractor system.</p>";
                            run_list();
                        }
                        else {
                            alert(data);
                        }
                    },
                    error: function() {
                        alert("An error occured during deleting document.");
                    }
                });
            });
        },
        error: function() {
            box.find(".state").html("<p class='error'>Couldn't retrieve document.</p>");
        }
    });

    var call = "get_document_state('" + id + "')";
    timeout = setTimeout(call, 60000);
}