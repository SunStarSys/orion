#!/usr/local/bin/node

/*
 * markdownd.js: Localhost TCP socket daemon responding to markdown inputs with html outputs.
 * thread-safe, with some dynamic window-passing hacking to editormd.js's ctor.
 * jQuery can be contextualized if you ask it nicely (key here is jsdom).
 * this runs forever, so daemonize it if needed.
 *
 * NPM Prerequisites: jsdom, navigator, and jquery.
 * Env Vars: EDITOR_MD, MARKDOWN_PORT
 * Example:
 *
 * % EDITOR_MD=editor.md MARKDOWN_PORT=9999 ./markdownd.js &
 *
 * SPDX License Identifier: Apache License 2.0
 */

const EDITOR_MD             = process.env.EDITOR_MD || __dirname + "/editor.md";
const MARKDOWN_PORT         = process.env.MARKDOWN_PORT || 2070;
const fs                    = require('fs');
const net                   = require('net');
const cluster               = require('cluster');
const nproc                 = require('os').cpus().length;

require.extensions['.css']  = function (module, filename) {
    module.exports = fs.readFileSync(filename, 'utf8');
};
require.extensions['.less'] = function (module, filename) {
    module.exports = fs.readFileSync(filename, 'utf8');
};

require.extensions['.html'] = function (module, filename) {
    module.exports = fs.readFileSync(filename, 'utf8');
};

global.IN_GLOBAL_SCOPE  = false;
global.navigator        = require("navigator");
global.jQuery           = require("jquery");

const { JSDOM } = jsdom = require('jsdom');

const EMD               = require(EDITOR_MD + "/editormd.js");
global.marked           = require(EDITOR_MD + "/lib/marked.min.js");
global.CodeMirror       = require(EDITOR_MD + "/lib/codemirror/codemirror.min.node.js");
global.CodeMirrorAddOns = require(EDITOR_MD + "/lib/codemirror/addons.min.js");
global.CodeMirrorModes  = require(EDITOR_MD + "/lib/codemirror/modes.min.js");
global.jQuery_flowchart = require(EDITOR_MD + "/lib/jquery.flowchart.min.js");
global.prettify         = require(EDITOR_MD + "/lib/prettify.js");
global.katex            = require(EDITOR_MD + "/lib/katex.min.js");
global.Raphael          = require(EDITOR_MD + "/lib/raphael.min.js");
global.flowchart        = require(EDITOR_MD + "/lib/flowchart.min.js");

const HTML =`<!doctype html>
<html>
<head></head>
<body><div id="editor"><textarea></textarea></div></body>
</html>
`;

const virtualConsole = new jsdom.VirtualConsole();
virtualConsole.sendTo(console);

if (cluster.isMaster) {
    console.log(`Master ${process.pid} is running`);

    for (let i = 0; i < nproc; i++) {
	cluster.fork();
    }

    cluster.on('exit', (worker, code, signal) => {
	console.log(`worker ${worker.process.pid} died`);
	cluster.fork();
    });
} else {
    console.log(`Worker ${process.pid} started`);
    const server = net.createServer(
	{ allowHalfOpen: true },
	(c) => {
            var markdown;
	    var mode = "gfm";
            c.on('data', (data) => {
		if (markdown) {
 		    markdown += data;
		}
		else {
		    markdown = data;
		}
	    });

            c.on('end', () => {
		const editormd = EMD(new JSDOM(HTML, { virtualConsole }).window);
		if (! markdown) { return c.end("\n"); }
		markdown = markdown.toString();
		const m  = markdown.match(/^(.{2,10})\x00(.+)$/s);
		if (m) {
		    mode     = m[1];
		    markdown = m[2];
		}
		const options = {
		    autoLoadModules: false,
		    readOnly:        true,
                    mode:            mode,
		    markdown:    markdown,
		    tocm :           true,
		    tex :            true,
		    searchReplace : false,
		    toolbar:        false,
		    // flowChart : true,
		    saveHTMLToTextarea: true,
		    htmlDecode :     true,
		    taskList:        true,
                    delay:              1,
		};
		if (mode != "gfm" || markdown.indexOf("\`\`\`") >= 0 || markdown.indexOf("\$\$") >= 0) {
		    const editor = editormd("editor", options, editormd);
		    setTimeout(function () {c.end(m ? editor.getHTML() : editor.getPreviewedHTML())}, m ? 5 : 100);
		}
		else {
		    options.saveHTMLToTextarea = false;
		    options.tex       = false;
		    options.flowChart = false;
		    const div = editormd.markdownToHTML("editor", options);
		    c.end(div.html());
		}
	    });
	});
    server.on('error', (err) => {
	console.log(err);
    });
    server.listen(MARKDOWN_PORT, "127.0.0.1", 128, () => {
    });
}
