(function(){
    var factory = function (exports) {
        var lang = {
            name : "de",
            description : "Open Source Online-Markdown-Editor.",
            tocTitle    : "Inhaltsverzeichnis",
            toolbar : {
                undo             : "Rückgängig (Ctrl+Z)",
                redo             : "Wiederherstellen (Ctrl+Y)",
                bold             : "Fett",
                del              : "Durchgestrichen",
                italic           : "Kursiv",
                quote            : "Angebot blockieren",
                ucwords          : "Wörter erster Buchstabe in Großbuchstaben konvertieren",
                uppercase        : "Auswahltext in Großbuchstaben konvertieren",
                lowercase        : "Auswahltext in Kleinbuchstaben konvertieren",
                h1               : "Überschrift 1",
                h2               : "Überschrift 2",
                h3               : "Überschrift 3",
                h4               : "Überschrift 4",
                h5               : "Überschrift 5",
                h6               : "Überschrift 6",
                "list_ul"        : "Unsortierte Liste",
                "list_ol"        : "Sortierte Liste",
                hr               : "Horizontale Regel",
                link             : "Verknüpfen",
                "reference_link" : "Referenzlink",
                image            : "Bild",
                comment          : "Angebotsauswahl für Kommentar",
                code             : "Inline-Code",
                "preformatted_text" : "Vorformatierter Text/Codeblock (Registerkarteneinzug)",
                "code_block"     : "Codeblock (Multisprachen)",
                table            : "Tabellen",
                datetime         : "Datum/Uhrzeit",
                emoji            : "Emoji",
                "html_entities"  : "HTML-Entitäten",
                pagebreak        : "Seitenumbruch",
                watch            : "Nicht beobachten",
                unwatch          : "Beobachten",
                preview          : "HTML-Vorschau (Umschalt + ESC beenden)",
                fullscreen       : "Vollbild (ESC beenden)",
                clear            : "Löschen",
                search           : "Suchen",
                help             : "Hilfe",
                info             : "Über uns" + ' ' + exports.title
            },

            buttons : {
                enter  : "Eingeben",
                cancel : "Abbrechen",
                close  : "Schließen"
            },
            dialog : {
                link : {
                    title    : "Verknüpfen",
                    url      : "Adresse",
                    urlTitle : "Titel",
                    urlEmpty : "Fehler: Geben Sie die Linkadresse ein."
                },
                referenceLink : {
                    title    : "Referenzlink",
                    name     : "Name",
                    url      : "Adresse",
                    urlId    : "Kennung",
                    urlTitle : "Titel",
                    nameEmpty: "Fehler: Referenzname darf nicht leer sein.",
                    idEmpty  : "Fehler: Geben Sie die Referenzlink-ID ein.",
                    urlEmpty : "Fehler: Geben Sie die URL-Adresse des Referenzlinks ein."
                },

                image : {
                    title    : "Bild",
                    url      : "Adresse",
                    link     : "Verknüpfen",
                    alt      : "Titel",
                    uploadButton     : "Hochladen",
                    imageURLEmpty    : "Fehler: Bild-URL-Adresse darf nicht leer sein.",
                    uploadFileEmpty  : "Fehler: Upload-Bilder dürfen nicht leer sein.",
                    formatNotAllowed : "Fehler: Ermöglicht nur das Hochladen der Bilddatei, das Hochladen des zulässigen Bilddateiformats:"
                },
                preformattedText : {
                    title             : "Vorformatierter Text/Codes",
                    emptyAlert        : "Fehler: Geben Sie den vorformatierten Text oder Inhalt der Codes ein.",
                    placeholder       : "Jetzt programmieren..."
                },
                codeBlock : {
                    title             : "Codeblock",
                    selectLabel       : "Sprachen: ",
                    selectDefaultText : "Code-Sprache auswählen...",
                    otherLanguage     : "Andere Sprachen",
                    unselectedLanguageAlert : "Fehler: Wählen Sie die Codesprache aus.",
                    codeEmptyAlert    : "Fehler: Geben Sie den Codeinhalt ein.",
                    placeholder       : "Jetzt programmieren..."
                },
                htmlEntities : {
                    title : "HTML-Entitäten"
                },
                help : {
                    title : "Hilfe"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "Funktion" && typeof exports === "Objekt" && typeof module === "Objekt")
    {
        module.exports = factory;
    }
	else if (typeof define === "Funktion")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["Editormd"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("../editormd");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

