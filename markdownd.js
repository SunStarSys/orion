#!/usr/local/bin/node

/*
 * markdownd.js: Unix socket daemon responding to markdown inputs with html outputs.
 * thread-safe, with some dynamic window-passing hacking to editormd.js's ctor.
 * jQuery is thread-safe if you ask it nicely (key here is jsdom).
 * this runs forever, so daemonize it if needed.
 *
 * NPM Prerequisites: jsdom, navigator, and jquery.
 * Env Vars: EDITOR_MD, MARKDOWN_SOCKET.
 * Example:
 *
 * % EDITOR_MD=editor.md MARKDOWN_SOCKET=markdown-socket ./markdownd.js &
 *
 * SPDX License Identifier: Apache License 2.0
 */

const EDITOR_MD             = process.env.EDITOR_MD       || "/x1/cms/webgui/content/editor.md";
const MARKDOWN_SOCKET       = process.env.MARKDOWN_SOCKET || "/x1/cms/run/markdown-socket";
const fs                    = require('fs');
const net                   = require('net');

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
const { JSDOM }         = require('jsdom');
const EMD               = require(EDITOR_MD + "/editormd.js");
global.marked           = require(EDITOR_MD + "/lib/marked.min.js");
global.CodeMirror       = require(EDITOR_MD + "/lib/codemirror/codemirror.min.js");
global.CodeMirrorAddOns = require(EDITOR_MD + "/lib/codemirror/addons.min.js");
global.CodeMirrorModes  = require(EDITOR_MD + "/lib/codemirror/modes.min.js");
global.jQuery_flowchart = require(EDITOR_MD + "/lib/jquery.flowchart.min.js");
global.prettify         = require(EDITOR_MD + "/lib/prettify.min.js");
global.katex            = require(EDITOR_MD + "/lib/katex.min.js");

if (fs.existsSync(MARKDOWN_SOCKET)) {
    fs.unlinkSync(MARKDOWN_SOCKET);
}

const HTML =`<!doctype html>
<html>
<head></head>
<body><div id="editor"><textarea></textarea></div></body>
</html>
`;

const server = net.createServer(
    { allowHalfOpen: true },
    (c) => {
        var markdown = "";

        c.on('data', (data) => {
            markdown += data.toString();//.replace(/@/g, '&#64;').replace(/([^\r])\n/g, "$1\r\n");
        });

        c.on('end', () => {
	    var jsdom = new JSDOM(HTML, {
		contentType: "text/html",
		pretendToBeVisual: true,
	    });
            var editormd = EMD(jsdom.window);
	    const options = {
		autoLoadModules: false,
		readOnly: true,
		markdown: markdown,
		tocm : true,
		tex : true,
		theme: "solarized",
		editorTheme: "solarized",
		previewTheme: "solarized",
		lineWrapping: false,
		lineNumbers: false,
		searchReplace : false,
		toolbar: false,
		flowChart : true,
		htmlDecode : "foo",
		taskList: true,		
	    };
	    if (markdown.indexOf('```') >= 0 || markdown.indexOf('$$') >= 0) {
		var editor = editormd("editor", options, editormd);
		c.end(editor.getPreviewedHTML());
	    }
	    else {
		options.tex = false;
		options.flowChart = false;		
		var div = editormd.markdownToHTML("editor", options);
		c.end(div.html());
	    }
	});
    });

server.on('error', (err) => {
    console.log(err);
});

server.listen(MARKDOWN_SOCKET, 128, () => {
    fs.chmodSync(MARKDOWN_SOCKET, 0o777);
});
