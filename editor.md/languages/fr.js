(function(){
    var factory = function (exports) {
        var lang = {
            name : "fr",
            description : "Editeur Markdown en ligne open source.",
            tocTitle    : "Table des matières",
            toolbar : {
                undo             : "Annuler(Ctrl+Z)",
                redo             : "Rétablir(Ctrl+Y)",
                bold             : "Gras",
                del              : "Barré",
                italic           : "Italique",
                quote            : "Guillemet de blocage",
                ucwords          : "Première lettre des mots convertie en majuscules",
                uppercase        : "Texte de sélection converti en majuscules",
                lowercase        : "Texte de sélection converti en minuscules",
                h1               : "Titre 1",
                h2               : "Titre 2",
                h3               : "Titre 3",
                h4               : "Titre 4",
                h5               : "Titre 5",
                h6               : "Titre 6",
                "list_ul"        : "Liste non triée",
                "list_ol"        : "Liste triée",
                hr               : "Règle horizontale",
                link             : "Lien",
                "reference_link" : "Lien de référence",
                image            : "Image",
                comment          : "Sélection de devis pour commentaire",
                code             : "Code incorporé",
                "preformatted_text" : "Texte préformaté / Bloc de code (indentation tabulaire)",
                "code_block"     : "Bloc de code (multi-langues)",
                table            : "Tables",
                datetime         : "Date/Heure",
                emoji            : "Emoji",
                "html_entities"  : "Entités HTML",
                pagebreak        : "Saut de page",
                watch            : "Déverrouiller",
                unwatch          : "Regarder",
                preview          : "Aperçu HTML (Appuyez sur Maj + Sortie ESC)",
                fullscreen       : "Plein écran (appuyez sur la sortie ESC)",
                clear            : "Effacer",
                search           : "Rechercher",
                help             : "Aide",
                info             : "À propos" + ' ' + exports.title
            },

            buttons : {
                enter  : "Entrer",
                cancel : "Annuler",
                close  : "Fermer"
            },
            dialog : {
                link : {
                    title    : "Lien",
                    url      : "Adresse",
                    urlTitle : "Titre",
                    urlEmpty : "Erreur : veuillez remplir l'adresse du lien."
                },
                referenceLink : {
                    title    : "Lien de référence",
                    name     : "Nom",
                    url      : "Adresse",
                    urlId    : "ID",
                    urlTitle : "Titre",
                    nameEmpty: "Erreur : le nom de référence ne peut pas être vide.",
                    idEmpty  : "Erreur : Renseignez l'ID lien de référence.",
                    urlEmpty : "Erreur : renseignez l'adresse URL du lien de référence."
                },

                image : {
                    title    : "Image",
                    url      : "Adresse",
                    link     : "Lien",
                    alt      : "Titre",
                    uploadButton     : "Charger",
                    imageURLEmpty    : "Erreur : l'adresse d'URL de l'image ne peut pas être vide.",
                    uploadFileEmpty  : "Erreur : le chargement des images ne peut pas être vide.",
                    formatNotAllowed : "Erreur : autorise uniquement le téléchargement de fichier d'images, format de fichier d'image autorisé pour le téléchargement :"
                },
                preformattedText : {
                    title             : "Texte / Codes préformatés",
                    emptyAlert        : "Erreur : veuillez remplir le texte ou le contenu préformaté des codes.",
                    placeholder       : "coder maintenant..."
                },
                codeBlock : {
                    title             : "Bloc de code",
                    selectLabel       : "Langues : ",
                    selectDefaultText : "sélectionner une langue de code...",
                    otherLanguage     : "Autres langues",
                    unselectedLanguageAlert : "Erreur : Sélectionnez la langue du code.",
                    codeEmptyAlert    : "Erreur : renseignez le contenu du code.",
                    placeholder       : "coder maintenant..."
                },
                htmlEntities : {
                    title : "Entités HTML"
                },
                help : {
                    title : "Aide"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "fonction" && typeof exports === "objet" && typeof module === "objet")
    {
        module.exports = factory;
    }
	else if (typeof define === "fonction")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["modificationorm"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("../modifier");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

