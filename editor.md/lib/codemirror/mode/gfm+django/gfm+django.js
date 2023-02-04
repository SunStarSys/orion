// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
      mod(require("../../lib/codemirror"), require("../django/django"), require("../gfm/gfm"),
        require("../../addon/mode/overlay"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror", "../gfm/gfm",
            "../../addon/mode/overlay"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
  "use strict";

  CodeMirror.defineMode("gfm+django", function(config) {
    var gfmBase = CodeMirror.getMode(config, "text/x-gfm");
    var djangoInner = CodeMirror.getMode(config, "django:inner");
    return CodeMirror.overlayMode(gfmBase, djangoInner);
  });

  CodeMirror.defineMIME("text/x-gfm+django", "gfm+django");
});
