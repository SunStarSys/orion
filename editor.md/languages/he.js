(function(){
    var factory = function (exports) {
        var lang = {
            name : "he",
            description : "עורך Markdown מקוון בקוד פתוח.",
            tocTitle    : "תוכן עניינים",
            toolbar : {
                undo             : "בטל(Ctrl+Z)",
                redo             : "בצע שוב(Ctrl+Y)",
                bold             : "מודגש",
                del              : "קו חוצה",
                italic           : "נטוי",
                quote            : "חסימת הצעת מחיר",
                ucwords          : "מילים אות ראשונה מומרות לאותיות גדולות",
                uppercase        : "המרת טקסט בחירה לאותיות רישיות",
                lowercase        : "המרת טקסט בחירה לאותיות קטנות",
                h1               : "כותרת 1",
                h2               : "כותרת 2",
                h3               : "כותרת 3",
                h4               : "כותרת 4",
                h5               : "כותרת 5",
                h6               : "כותרת 6",
                "list_ul"        : "רשימה לא מסודרת",
                "list_ol"        : "רשימה מסודרת",
                hr               : "כלל אופקי",
                link             : "קישור",
                "reference_link" : "קישור הפניה",
                image            : "תמונה",
                comment          : "בחירת הצעת מחיר להערה",
                code             : "קוד בתוך השורה",
                "preformatted_text" : "טקסט מעוצב מראש / בלוק קוד (כניסת טאב)",
                "code_block"     : "בלוק קוד (שפות מרובות)",
                table            : "טבלאות",
                datetime         : "תאריך ושעה",
                emoji            : "אמוג'י",
                "html_entities"  : "ישויות HTML",
                pagebreak        : "מעבר עמוד",
                watch            : "בטל מעקב",
                unwatch          : "מעקב",
                preview          : "תצוגה מקדימה של HTML (הקש Shift + יציאת ESC)",
                fullscreen       : "מסך מלא (לחץ על 'יציאת ESC')",
                clear            : "נקה",
                search           : "חיפוש",
                help             : "עזרה",
                info             : "אודות" + ' ' + exports.title
            },

            buttons : {
                enter  : "הזן",
                cancel : "ביטול",
                close  : "סגור"
            },
            dialog : {
                link : {
                    title    : "קישור",
                    url      : "כתובת",
                    urlTitle : "כותרת",
                    urlEmpty : "שגיאה: מלא את כתובת הקישור."
                },
                referenceLink : {
                    title    : "קישור הפניה",
                    name     : "שם",
                    url      : "כתובת",
                    urlId    : "מזהה",
                    urlTitle : "כותרת",
                    nameEmpty: "שגיאה: שם ההפניה לא יכול להיות ריק.",
                    idEmpty  : "שגיאה: מלא את מזהה קישור ההפניה.",
                    urlEmpty : "שגיאה: מלא את כתובת ה-URL של קישור ההפניה."
                },

                image : {
                    title    : "תמונה",
                    url      : "כתובת",
                    link     : "קישור",
                    alt      : "כותרת",
                    uploadButton     : "טען",
                    imageURLEmpty    : "שגיאה: כתובת URL של תמונה לא יכולה להיות ריקה.",
                    uploadFileEmpty  : "שגיאה: העלאת תמונות לא יכולה להיות ריקה!",
                    formatNotAllowed : "שגיאה: מאפשר להעלות קובץ תמונות בלבד, להעלות תבנית קובץ תמונה מותרת:"
                },
                preformattedText : {
                    title             : "טקסט / קודים מעוצבים מראש",
                    emptyAlert        : "שגיאה: מלא את הטקסט או את תוכן הקודים המעוצבים מראש.",
                    placeholder       : "כתיבת קוד עכשיו..."
                },
                codeBlock : {
                    title             : "בלוק קוד",
                    selectLabel       : "שפות: ",
                    selectDefaultText : "בחר שפת קוד...",
                    otherLanguage     : "שפות אחרות",
                    unselectedLanguageAlert : "שגיאה: בחר את שפת הקוד.",
                    codeEmptyAlert    : "שגיאה: מלא את תוכן הקוד.",
                    placeholder       : "כתיבת קוד עכשיו..."
                },
                htmlEntities : {
                    title : "ישויות HTML"
                },
                help : {
                    title : "עזרה"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "פונקציה" && typeof exports === "עצם" && typeof module === "עצם")
    {
        module.exports = factory;
    }
	else if (typeof define === "פונקציה")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["ערוך סערה"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("סטנסיליםStencils");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

