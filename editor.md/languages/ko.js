(function(){
    var factory = function (exports) {
        var lang = {
            name : "ko",
            description : "오픈 소스 온라인 마크다운 편집기입니다.",
            tocTitle    : "목차",
            toolbar : {
                undo             : "실행 취소(Ctrl+Z)",
                redo             : "리두(Ctrl+Y)",
                bold             : "굵게",
                del              : "취소선",
                italic           : "기울임꼴",
                quote            : "블록 인용구",
                ucwords          : "단어 첫 글자가 대문자로 변환됨",
                uppercase        : "선택 텍스트가 대문자로 변환됩니다.",
                lowercase        : "선택 텍스트가 소문자로 변환됨",
                h1               : "제목1",
                h2               : "제목2",
                h3               : "제목3",
                h4               : "제목4",
                h5               : "제목5",
                h6               : "제목6",
                "list_ul"        : "순서없는 목록",
                "list_ol"        : "정렬된 목록",
                hr               : "수평 규칙",
                link             : "링크",
                "reference_link" : "참조 링크",
                image            : "이미지",
                comment          : "의견에 대한 견적 선택",
                code             : "코드 인라인",
                "preformatted_text" : "사전 형식이 지정된 텍스트/코드 블록(탭 들여쓰기)",
                "code_block"     : "코드 블록(다중 언어)",
                table            : "테이블",
                datetime         : "날짜/시간",
                emoji            : "이모지",
                "html_entities"  : "HTML 엔터티",
                pagebreak        : "페이지 구분",
                watch            : "감시 해제",
                unwatch          : "보기",
                preview          : "HTML 미리보기(Shift + ESC 종료 누르기)",
                fullscreen       : "전체 화면(ESC 종료 누르기)",
                clear            : "지우기",
                search           : "검색",
                help             : "도움말",
                info             : "정보" + ' ' + exports.title
            },

            buttons : {
                enter  : "Name 필드에",
                cancel : "취소",
                close  : "닫기"
            },
            dialog : {
                link : {
                    title    : "링크",
                    url      : "주소",
                    urlTitle : "제목",
                    urlEmpty : "오류: 링크 주소를 입력하십시오."
                },
                referenceLink : {
                    title    : "참조 링크",
                    name     : "이름",
                    url      : "주소",
                    urlId    : "ID",
                    urlTitle : "제목",
                    nameEmpty: "오류: 참조 이름은 비워 둘 수 없습니다.",
                    idEmpty  : "오류: 참조 링크 ID를 입력하십시오.",
                    urlEmpty : "오류: 참조 링크 URL 주소를 입력하십시오."
                },

                image : {
                    title    : "이미지",
                    url      : "주소",
                    link     : "링크",
                    alt      : "제목",
                    uploadButton     : "업로드",
                    imageURLEmpty    : "오류: 그림 URL 주소는 비워 둘 수 없습니다.",
                    uploadFileEmpty  : "오류: 사진 업로드는 비워 둘 수 없습니다!",
                    formatNotAllowed : "오류: 사진 파일 업로드만 허용하고 허용된 이미지 파일 형식 업로드:"
                },
                preformattedText : {
                    title             : "사전 형식 지정된 텍스트/코드",
                    emptyAlert        : "오류: 사전 형식 지정된 텍스트 또는 코드 콘텐츠를 입력하십시오.",
                    placeholder       : "지금 코딩하는 중..."
                },
                codeBlock : {
                    title             : "코드 블록",
                    selectLabel       : "언어: ",
                    selectDefaultText : "코드 언어 선택...",
                    otherLanguage     : "다른 언어 보기",
                    unselectedLanguageAlert : "오류: 코드 언어를 선택하십시오.",
                    codeEmptyAlert    : "오류: 코드 내용을 입력하십시오.",
                    placeholder       : "지금 코딩하는 중..."
                },
                htmlEntities : {
                    title : "HTML 엔터티"
                },
                help : {
                    title : "도움말"
                }
            }
        };

        exports.defaults.lang = lang;
    };

	// CommonJS/Node.js
	if (typeof require === "함수" && typeof exports === "객체" && typeof module === "객체")
    {
        module.exports = factory;
    }
	else if (typeof define === "함수")  // AMD/CMD/Sea.js
    {
		if (define.amd) { // for Require.js

			define(["편집자"], function(editormd) {
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

