(function(){
    var factory = function (exports) {
        var lang = {
            name : "ja",
            description : "オープンソースのオンラインMarkdownエディタ。",
            tocTitle    : "目次",
            toolbar : {
                undo             : "UNDO(Ctrl+Z)",
                redo             : "REDO(Ctrl+Y)",
                bold             : "太字",
                del              : "取り消し線",
                italic           : "斜体",
                quote            : "ブロック引用",
                ucwords          : "単語の最初の文字は大文字に変換されます",
                uppercase        : "選択テキストを大文字に変換",
                lowercase        : "選択テキストを小文字に変換",
                h1               : "見出し1",
                h2               : "見出し2",
                h3               : "見出し3",
                h4               : "見出し4",
                h5               : "見出し5",
                h6               : "見出し6",
                "list_ul"        : "順序なしリスト",
                "list_ol"        : "順序付きリスト",
                hr               : "水平ルール",
                link             : "リンク",
                "reference_link" : "参照リンク",
                image            : "画像",
                comment          : "コメント用の見積選択",
                code             : "コード・インライン",
                "preformatted_text" : "事前フォーマット済テキスト/コード・ブロック(タブ・インデント)",
                "code_block"     : "コード・ブロック(複数言語)",
                table            : "テーブル",
                datetime         : "日時",
                emoji            : "エモジ",
                "html_entities"  : "HTMLエンティティ",
                pagebreak        : "改ページ",
                watch            : "監視解除",
                unwatch          : "監視",
                preview          : "HTMLプレビュー([Shift]を押しながら[ESC]を終了)",
                fullscreen       : "全画面表示(ESCを押す)",
                clear            : "消去",
                search           : "検索",
                help             : "ヘルプ",
                info             : "情報" + ' ' + exports.title
            },

            buttons : {
                enter  : "入力",
                cancel : "取消",
                close  : "閉じる"
            },
            dialog : {
                link : {
                    title    : "リンク",
                    url      : "住所",
                    urlTitle : "タイトル",
                    urlEmpty : "エラー: リンク・アドレスを入力してください。"
                },
                referenceLink : {
                    title    : "参照リンク",
                    name     : "名前",
                    url      : "住所",
                    urlId    : "ID",
                    urlTitle : "タイトル",
                    nameEmpty: "エラー: 参照名は空にできません。",
                    idEmpty  : "エラー: 参照リンクIDを入力してください。",
                    urlEmpty : "エラー: 参照リンクURLアドレスを入力してください。"
                },

                image : {
                    title    : "画像",
                    url      : "住所",
                    link     : "リンク",
                    alt      : "タイトル",
                    uploadButton     : "アップロード",
                    imageURLEmpty    : "エラー: 画像URLアドレスは空にできません。",
                    uploadFileEmpty  : "エラー: アップロード画像は空にできません!",
                    formatNotAllowed : "エラー: 画像ファイルをアップロードするだけで、許可されている画像ファイル形式をアップロードできます:"
                },
                preformattedText : {
                    title             : "事前フォーマット済テキスト/コード",
                    emptyAlert        : "エラー: 事前に書式設定されたテキストまたはコードの内容を入力してください。",
                    placeholder       : "今のコーディング…"
                },
                codeBlock : {
                    title             : "コード・ブロック",
                    selectLabel       : "言語: ",
                    selectDefaultText : "コード言語を選択...",
                    otherLanguage     : "他の言語",
                    unselectedLanguageAlert : "エラー: コード言語を選択してください。",
                    codeEmptyAlert    : "エラー: コードの内容を入力してください。",
                    placeholder       : "今のコーディング…"
                },
                htmlEntities : {
                    title : "HTMLエンティティ"
                },
                help : {
                    title : "ヘルプ"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "集まり" && typeof exports === "オブジェクト" && typeof module === "オブジェクト")
    {
        module.exports = factory;
    }
	else if (typeof define === "集まり")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["editormd"], function(editormd) {
                factory(editormd);
            });

		} else { // for Sea.js
			define(function(require) {
                var editormd = require("./editormd");
                factory(editormd);
            });
		}
	}
	else
	{
        factory(window.editormd);
	}

})();

