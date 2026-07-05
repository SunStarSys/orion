(function(){
    var factory = function (exports) {
        var lang = {
            name : "ru",
            description : "Онлайн-редактор Markdown с открытым исходным кодом.",
            tocTitle    : "Содержание",
            toolbar : {
                undo             : "Отменить(Ctrl+Z)",
                redo             : "Вернуть(Ctrl+Y)",
                bold             : "Полужирный",
                del              : "Зачёркивание",
                italic           : "Курсив",
                quote            : "Блокировать котировку",
                ucwords          : "Первая буква слов преобразуется в прописные буквы",
                uppercase        : "Текст выделения преобразуется в прописные",
                lowercase        : "Текст выделения преобразуется в нижний регистр",
                h1               : "Заголовок 1",
                h2               : "Заголовок 2",
                h3               : "Заголовок 3",
                h4               : "Заголовок 4",
                h5               : "Заголовок 5",
                h6               : "Заголовок 6",
                "list_ul"        : "Неупорядоченный список",
                "list_ol"        : "Нумерованный список",
                hr               : "Горизонтальное правило",
                link             : "Ссылка",
                "reference_link" : "Ссылка",
                image            : "Изображение",
                comment          : "Выбор котировки для примечания",
                code             : "Встроенный код",
                "preformatted_text" : "Предварительно отформатированный текст/блок кода (отступ вкладки)",
                "code_block"     : "Блок кода (многоязычный)",
                table            : "Таблицами",
                datetime         : "Дата/время",
                emoji            : "Эмодзи",
                "html_entities"  : "Объекты HTML",
                pagebreak        : "Разрыв страницы",
                watch            : "Отменить наблюдение",
                unwatch          : "Отслеживать",
                preview          : "Предварительный просмотр HTML (нажмите Shift + выход ESC)",
                fullscreen       : "Полный экран (нажмите ESC exit)",
                clear            : "Очистить",
                search           : "Поиск",
                help             : "Справка",
                info             : "О нас" + ' ' + exports.title
            },

            buttons : {
                enter  : "Ввод",
                cancel : "Отмена",
                close  : "Закрыть"
            },
            dialog : {
                link : {
                    title    : "Ссылка",
                    url      : "Адрес",
                    urlTitle : "Должность",
                    urlEmpty : "Ошибка: Пожалуйста, введите адрес ссылки."
                },
                referenceLink : {
                    title    : "Ссылка",
                    name     : "Имя",
                    url      : "Адрес",
                    urlId    : "Идентификатор",
                    urlTitle : "Должность",
                    nameEmpty: "Ошибка: имя ссылки не может быть пустым.",
                    idEmpty  : "Ошибка: введите идентификатор ссылки ссылки.",
                    urlEmpty : "Ошибка: введите URL-адрес ссылки."
                },

                image : {
                    title    : "Изображение",
                    url      : "Адрес",
                    link     : "Ссылка",
                    alt      : "Должность",
                    uploadButton     : "Загрузить",
                    imageURLEmpty    : "Ошибка: адрес URL изображения не может быть пустым.",
                    uploadFileEmpty  : "Ошибка: загружаемые изображения не могут быть пустыми!",
                    formatNotAllowed : "Ошибка: позволяет загружать только файлы изображений, загружать разрешенный формат файла изображения:"
                },
                preformattedText : {
                    title             : "Предварительно отформатированный текст/коды",
                    emptyAlert        : "Ошибка: Заполните предварительно отформатированный текст или содержимое кодов.",
                    placeholder       : "кодирование сейчас..."
                },
                codeBlock : {
                    title             : "Блок кода",
                    selectLabel       : "Языки: ",
                    selectDefaultText : "выберите язык кода...",
                    otherLanguage     : "Другие языки",
                    unselectedLanguageAlert : "Ошибка: выберите язык кода.",
                    codeEmptyAlert    : "Ошибка: Пожалуйста, заполните содержимое кода.",
                    placeholder       : "кодирование сейчас..."
                },
                htmlEntities : {
                    title : "Объекты HTML"
                },
                help : {
                    title : "Справка"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "вечеринка" && typeof exports === "объект" && typeof module === "объект")
    {
        module.exports = factory;
    }
	else if (typeof define === "вечеринка")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["редактирование"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("../редактирование");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

