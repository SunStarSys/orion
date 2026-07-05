(function(){
    var factory = function (exports) {
        var lang = {
            name : "in",
            description : "Editor de Markdown on-line de código aberto.",
            tocTitle    : "Sumário",
            toolbar : {
                undo             : "Desfazer(Ctrl+Z)",
                redo             : "Refazer (Ctrl+Y)",
                bold             : "Negrito",
                del              : "Tachado",
                italic           : "Itálico",
                quote            : "Cotação em bloco",
                ucwords          : "Palavras primeira letra converter para maiúscula",
                uppercase        : "Texto de seleção convertido em letras maiúsculas",
                lowercase        : "Texto de seleção convertido em letras minúsculas",
                h1               : "Título 1",
                h2               : "Título 2",
                h3               : "Título 3",
                h4               : "Título 4",
                h5               : "Título 5",
                h6               : "Título 6",
                "list_ul"        : "Lista não ordenada",
                "list_ol"        : "Lista ordenada",
                hr               : "Regra horizontal",
                link             : "Link",
                "reference_link" : "Link de referência",
                image            : "Imagem",
                comment          : "Seleção de Cotação para Comentário",
                code             : "Código em linha",
                "preformatted_text" : "Texto pré-formatado / Bloco de código (Recuo da guia)",
                "code_block"     : "Bloco de código (Multilinguagens)",
                table            : "Tabelas",
                datetime         : "Data/hora",
                emoji            : "Emoji",
                "html_entities"  : "Entidades HTML",
                pagebreak        : "Quebra de página",
                watch            : "Não assistir",
                unwatch          : "Assistir",
                preview          : "Visualização HTML (Pressione Shift + saída ESC)",
                fullscreen       : "Tela inteira (Pressione ESC exit)",
                clear            : "Limpar",
                search           : "Pesquisar",
                help             : "Ajuda",
                info             : "Sobre" + ' ' + exports.title
            },

            buttons : {
                enter  : "Informar",
                cancel : "Cancelar",
                close  : "Fechar"
            },
            dialog : {
                link : {
                    title    : "Link",
                    url      : "Endereço",
                    urlTitle : "Título",
                    urlEmpty : "Erro: Preencha o endereço do link."
                },
                referenceLink : {
                    title    : "Link de referência",
                    name     : "Nome",
                    url      : "Endereço",
                    urlId    : "ID",
                    urlTitle : "Título",
                    nameEmpty: "Erro: O nome da referência não pode ficar vazio.",
                    idEmpty  : "Erro: Preencha o ID do link de referência.",
                    urlEmpty : "Erro: Preencha o endereço do URL do link de referência."
                },

                image : {
                    title    : "Imagem",
                    url      : "Endereço",
                    link     : "Link",
                    alt      : "Título",
                    uploadButton     : "Fazer Upload",
                    imageURLEmpty    : "Erro: o endereço do url da imagem não pode ficar vazio.",
                    uploadFileEmpty  : "Erro: upload de imagens não pode ficar vazio!",
                    formatNotAllowed : "Erro: permite apenas fazer upload do arquivo de imagens, upload do formato de arquivo de imagem permitido:"
                },
                preformattedText : {
                    title             : "Texto/códigos pré-formatados",
                    emptyAlert        : "Erro: Preencha o texto pré-formatado ou o conteúdo dos códigos.",
                    placeholder       : "codificando agora..."
                },
                codeBlock : {
                    title             : "Bloco de código",
                    selectLabel       : "Idiomas: ",
                    selectDefaultText : "selecione um idioma de código...",
                    otherLanguage     : "Outros idiomas",
                    unselectedLanguageAlert : "Erro: Selecione o idioma do código.",
                    codeEmptyAlert    : "Erro: Por favor, preencha o conteúdo do código.",
                    placeholder       : "codificando agora..."
                },
                htmlEntities : {
                    title : "Entidades HTML"
                },
                help : {
                    title : "Ajuda"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "função" && typeof exports === "objeto" && typeof module === "objeto")
    {
        module.exports = factory;
    }
	else if (typeof define === "função")  // AMD/CMD/Sea.js
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

