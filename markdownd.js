#!/usr/bin/env node

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

const HTML = `<html><body><div id="editor"><textarea></textarea></div></body></html>`;
const { JSDOM }             = require('jsdom');

global.jQuery               = require('jquery');
global.navigator            = require('navigator');
global.marked               = require(EDITOR_MD + "/lib/marked.min.js");

const emd                   = require(EDITOR_MD + "/editormd.js");

if (fs.existsSync(MARKDOWN_SOCKET)) {
    fs.unlinkSync(MARKDOWN_SOCKET);
}

const server = net.createServer(
    { allowHalfOpen: true },
    (c) => {
        var markdown = "";

        c.on('data', (data) => {
            markdown += data.toString();
        });

        c.on('end', () => {
            const e = new emd(new JSDOM(HTML).window);
            const div = e.markdownToHTML("editor", {
                markdown: markdown,
                previewCodeHighlight: false,
            });
            c.end(div.html());
        });
    });

server.on('error', (err) => {
    console.log(err);
});

server.listen(MARKDOWN_SOCKET, 128, () => {
    fs.chmodSync(MARKDOWN_SOCKET, 0o777);
});
