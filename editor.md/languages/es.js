(function(){
    var factory = function (exports) {
        var lang = {
            name : "es",
            description : "Editor de Markdown en línea de código abierto.",
            tocTitle    : "Tabla de contenido",
            toolbar : {
                undo             : "Deshacer(Ctrl+Z)",
                redo             : "Rehacer(Ctrl+Y)",
                bold             : "Negrita",
                del              : "Tachado",
                italic           : "Cursiva",
                quote            : "Bloquear oferta económica",
                ucwords          : "La primera letra de las palabras se convierte a mayúsculas",
                uppercase        : "El texto de selección se convierte a mayúsculas",
                lowercase        : "El texto de selección se convierte a minúsculas",
                h1               : "Encabezado 1",
                h2               : "Encabezado 2",
                h3               : "Encabezado 3",
                h4               : "Encabezado 4",
                h5               : "Encabezado 5",
                h6               : "Encabezado 6",
                "list_ul"        : "Lista desordenada",
                "list_ol"        : "Lista ordenada",
                hr               : "Regla horizontal",
                link             : "Enlace",
                "reference_link" : "Enlace de referencia",
                image            : "Imagen",
                comment          : "Selección de oferta económica para comentario",
                code             : "Código en línea",
                "preformatted_text" : "Texto con formato previo / Bloque de código ( sangría de separador)",
                "code_block"     : "Bloque de código (varios idiomas)",
                table            : "Tablas",
                datetime         : "Fecha y hora",
                emoji            : "Emoji",
                "html_entities"  : "Entidades HTML",
                pagebreak        : "Salto de página",
                watch            : "Desmontar",
                unwatch          : "Ver",
                preview          : "Vista previa de HTML (presione Mayús + ESC)",
                fullscreen       : "Pantalla completa (Pulse la salida ESC)",
                clear            : "Borrar",
                search           : "Buscar",
                help             : "Ayuda",
                info             : "Acerca de" + ' ' + exports.title
            },

            buttons : {
                enter  : "Introducir",
                cancel : "Cancelar",
                close  : "Cerrar"
            },
            dialog : {
                link : {
                    title    : "Enlace",
                    url      : "Dirección",
                    urlTitle : "Título",
                    urlEmpty : "Error: Rellene la dirección del enlace."
                },
                referenceLink : {
                    title    : "Enlace de referencia",
                    name     : "Nombre",
                    url      : "Dirección",
                    urlId    : "ID",
                    urlTitle : "Título",
                    nameEmpty: "Error: el nombre de referencia no puede estar vacío.",
                    idEmpty  : "Error: rellene la Id. de enlace de referencia.",
                    urlEmpty : "Error: rellene la dirección URL del enlace de referencia."
                },

                image : {
                    title    : "Imagen",
                    url      : "Dirección",
                    link     : "Enlace",
                    alt      : "Título",
                    uploadButton     : "Cargar",
                    imageURLEmpty    : "Error: la dirección URL de imagen no puede estar vacía.",
                    uploadFileEmpty  : "Error: las imágenes de carga no pueden estar vacías.",
                    formatNotAllowed : "Error: solo permite cargar archivos de imágenes, cargar formato de archivo de imagen permitido:"
                },
                preformattedText : {
                    title             : "Texto/códigos con formato previo",
                    emptyAlert        : "Error: rellene el texto con formato previo o el contenido de los códigos.",
                    placeholder       : "codificando ahora..."
                },
                codeBlock : {
                    title             : "Bloque de código",
                    selectLabel       : "Idiomas: ",
                    selectDefaultText : "seleccionar un idioma de código...",
                    otherLanguage     : "Otros idiomas",
                    unselectedLanguageAlert : "Error: seleccione el idioma del código.",
                    codeEmptyAlert    : "Error: Por favor, rellene el contenido del código.",
                    placeholder       : "codificando ahora..."
                },
                htmlEntities : {
                    title : "Entidades HTML"
                },
                help : {
                    title : "Ayuda"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "función" && typeof exports === "objeto" && typeof module === "objeto")
    {
        module.exports = factory;
    }
	else if (typeof define === "función")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["editormd"], function(editormd) {
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

