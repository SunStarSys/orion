(function(){
    var factory = function (exports) {
        var lang = {
            name : "ar",
            description : "محرر Markdown عبر الإنترنت مفتوح المصدر.",
            tocTitle    : "جدول المحتويات",
            toolbar : {
                undo             : "تراجع(Ctrl+Z)",
                redo             : "أعِد(Ctrl+Y)",
                bold             : "عريض",
                del              : "مشطوب",
                italic           : "مائل",
                quote            : "حظر عرض الأسعار",
                ucwords          : "يتم تحويل الحرف الأول من الكلمات إلى أحرف كبيرة",
                uppercase        : "تحويل نص التحديد إلى حروف كبيرة",
                lowercase        : "تحويل نص التحديد إلى حروف صغيرة",
                h1               : "رأس 1",
                h2               : "رأس 2",
                h3               : "رأس 3",
                h4               : "رأس 4",
                h5               : "رأس 5",
                h6               : "رأس 6",
                "list_ul"        : "قائمة غير مرتبة",
                "list_ol"        : "قائمة مرتبة",
                hr               : "قاعدة أفقية",
                link             : "رابط",
                "reference_link" : "ارتباط المرجع",
                image            : "الصورة",
                comment          : "تحديد عرض الأسعار للتعليق",
                code             : "التعليمات البرمجية مضمنة",
                "preformatted_text" : "كتلة التعليمة البرمجية/النص المنسق مسبقًا (مسافة بادئة لعلامة التبويب)",
                "code_block"     : "كتلة التعليمات البرمجية (عدة لغات)",
                table            : "الجداول",
                datetime         : "التاريخ/الوقت",
                emoji            : "إيموجي",
                "html_entities"  : "كيانات HTML",
                pagebreak        : "فاصل صفحات",
                watch            : "إلغاء المراقبة",
                unwatch          : "راقب",
                preview          : "معاينة HTML (اضغط على Shift + ESC exit)",
                fullscreen       : "ملء الشاشة (اضغط على ESC exit)",
                clear            : "مسح",
                search           : "بحث",
                help             : "التعليمات",
                info             : "حول" + ' ' + exports.title
            },

            buttons : {
                enter  : "إدخال",
                cancel : "إلغاء",
                close  : "إغلاق"
            },
            dialog : {
                link : {
                    title    : "رابط",
                    url      : "العنوان",
                    urlTitle : "العنوان",
                    urlEmpty : "خطأ: الرجاء ملء عنوان الرابط."
                },
                referenceLink : {
                    title    : "ارتباط المرجع",
                    name     : "الاسم",
                    url      : "العنوان",
                    urlId    : "المعرف",
                    urlTitle : "العنوان",
                    nameEmpty: "خطأ: لا يمكن أن يكون اسم المرجع فارغًا.",
                    idEmpty  : "خطأ: الرجاء ملء معرف ارتباط المرجع.",
                    urlEmpty : "خطأ: الرجاء ملء عنوان url لرابط المرجع."
                },

                image : {
                    title    : "الصورة",
                    url      : "العنوان",
                    link     : "رابط",
                    alt      : "العنوان",
                    uploadButton     : "تحميل",
                    imageURLEmpty    : "خطأ: لا يمكن أن يكون عنوان url للصورة فارغًا.",
                    uploadFileEmpty  : "خطأ: لا يمكن أن يكون تحميل الصور فارغًا!",
                    formatNotAllowed : "خطأ: يسمح فقط بتحميل ملف الصور، وتحميل تنسيق ملف الصورة المسموح به:"
                },
                preformattedText : {
                    title             : "نص / رموز منسقة مسبقًا",
                    emptyAlert        : "خطأ: الرجاء ملء النص المنسق مسبقًا أو محتوى الرموز.",
                    placeholder       : "الترميز الآن...."
                },
                codeBlock : {
                    title             : "كتلة التعليمة البرمجية",
                    selectLabel       : "اللغات: ",
                    selectDefaultText : "اختر لغة رمز...",
                    otherLanguage     : "لغات أخرى",
                    unselectedLanguageAlert : "خطأ: الرجاء تحديد لغة الكود.",
                    codeEmptyAlert    : "خطأ: الرجاء ملء محتوى الكود.",
                    placeholder       : "الترميز الآن...."
                },
                htmlEntities : {
                    title : "كيانات HTML"
                },
                help : {
                    title : "التعليمات"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "وظيفة" && typeof exports === "كائن" && typeof module === "كائن")
    {
        module.exports = factory;
    }
	else if (typeof define === "وظيفة")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["حراري"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("../تحريرormd");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

