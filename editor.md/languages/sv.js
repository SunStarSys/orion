(function(){
    var factory = function (exports) {
        var lang = {
            name : "sv",
            description : "Nedsättningsredigerare online med öppen källkod.",
            tocTitle    : "Innehållsförteckning",
            toolbar : {
                undo             : "Ångra(Ctrl+Z)",
                redo             : "Gör om(Ctrl+Y)",
                bold             : "Djärvt",
                del              : "Genomstrykning",
                italic           : "Kursiv",
                quote            : "Blockera citat",
                ucwords          : "Ord som första bokstav konverterar till versaler",
                uppercase        : "Urvalstext, konvertera till versaler",
                lowercase        : "Urvalstext, konvertera till gemener",
                h1               : "Rubrik 1",
                h2               : "Rubrik 2",
                h3               : "Rubrik 3",
                h4               : "Rubrik 4",
                h5               : "Rubrik 5",
                h6               : "Rubrik 6",
                "list_ul"        : "Osorterad lista",
                "list_ol"        : "Sorterad lista",
                hr               : "Horisontell regel",
                link             : "Länk",
                "reference_link" : "Referenslänk",
                image            : "Bild",
                comment          : "Offertval för kommentar",
                code             : "Kod infogad",
                "preformatted_text" : "Förformaterad text/kodblock (flikindrag)",
                "code_block"     : "Kodblock (flerspråkiga)",
                table            : "Tabeller",
                datetime         : "Datum/tid",
                emoji            : "Emoji",
                "html_entities"  : "HTML-entiteter",
                pagebreak        : "Sidbrytning",
                watch            : "Ta bort klocka",
                unwatch          : "Bevaka",
                preview          : "HTML-förhandsgranskning (tryck på Skift + ESC-avslutning)",
                fullscreen       : "Helskärm (tryck på ESC-utgång)",
                clear            : "Rensa",
                search           : "Sök",
                help             : "Hjälp",
                info             : "Om" + ' ' + exports.title
            },

            buttons : {
                enter  : "Ange",
                cancel : "Avbryt",
                close  : "Stäng"
            },
            dialog : {
                link : {
                    title    : "Länk",
                    url      : "Adress",
                    urlTitle : "Rubrik",
                    urlEmpty : "Fel: Fyll i länkadressen."
                },
                referenceLink : {
                    title    : "Referenslänk",
                    name     : "Namn",
                    url      : "Adress",
                    urlId    : "ID",
                    urlTitle : "Rubrik",
                    nameEmpty: "Fel: Referensnamn måste anges.",
                    idEmpty  : "Fel: Fyll i referenslänk-id:t.",
                    urlEmpty : "Fel: Fyll i URL-adressen för referenslänken."
                },

                image : {
                    title    : "Bild",
                    url      : "Adress",
                    link     : "Länk",
                    alt      : "Rubrik",
                    uploadButton     : "Ladda upp",
                    imageURLEmpty    : "Fel: bildens webbadress får inte vara tom.",
                    uploadFileEmpty  : "Fel: uppladdningsbilder måste anges!",
                    formatNotAllowed : "Fel: tillåter endast uppladdning av bildfil, uppladdning tillåten bildfilformat:"
                },
                preformattedText : {
                    title             : "Förformaterad text/koder",
                    emptyAlert        : "Fel: Fyll i förformaterad text eller kodens innehåll.",
                    placeholder       : "Kodar nu..."
                },
                codeBlock : {
                    title             : "Kodblock",
                    selectLabel       : "Språk: ",
                    selectDefaultText : "välj ett kodspråk...",
                    otherLanguage     : "Andra språk",
                    unselectedLanguageAlert : "Fel: Välj kodspråk.",
                    codeEmptyAlert    : "Fel: Fyll i kodinnehållet.",
                    placeholder       : "Kodar nu..."
                },
                htmlEntities : {
                    title : "HTML-entiteter"
                },
                help : {
                    title : "Hjälp"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "funktion" && typeof exports === "objekt" && typeof module === "objekt")
    {
        module.exports = factory;
    }
	else if (typeof define === "funktion")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["redigeringsmask"], function(editormd) {
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

