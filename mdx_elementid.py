#! 
# coding:utf-8

'''
id Extension for Python-Markdown
==========================================

This extension adds ids to block elements in Python-Markdown.

Simple Usage:

    >>> import markdown
    >>> def _strip_SECTIONLINK_CSS(str):
    ...     return str.split("</style>\\n", 2)[1]
    >>> text = """
    ... list: {#list.1} 
    ...
    ... 1. This is a test {#node1}
    ... 2. Other {.node2 node3}
    ... # Download! # [#downloading]
    ... 
    ... More
    ... """
    >>> _strip_SECTIONLINK_CSS(markdown.markdown(text, ['toc','elementid']))
    u'<p id="list.1">list:</p>\\n<ol>\\n<li id="node1">This is a test</li>\\n<li class="node2 node3">Other</li>\\n</ol>\\n<h1 id="downloading">Download! <a class="elementid-sectionlink" href="#downloading" title="Link to this section">&para;</a></h1>\\n<p>More</p>'
    >>> text2 = u"""Spain {#el1}
    ... :    Name of a country
    ...      in the South West of Europe
    ... 
    ... Espa\xf1a {#el2}
    ... :    Name of Spain
    ...      in Spanish (contains non-ascii)
    ... 
    ... End of definition list...
    ... """
    >>> _strip_SECTIONLINK_CSS(markdown.markdown(text2, ['toc','elementid', 'def_list']))
    u'<dl>\\n<dt id="el1">Spain</dt>\\n<dd>Name of a country\\n in the South West of Europe</dd>\\n<dt id="el2">Espa\\xf1a</dt>\\n<dd>Name of Spain\\n in Spanish (contains non-ascii)</dd>\\n</dl>\\n<p>End of definition list...</p>'



Copyright 2010
* [Santiago Gala](http://memojo.com/~sgala/blog/)

'''

import markdown, re
from markdown.util import etree
import markdown.extensions
from markdown.util import isBlockLevel

# Global Vars
ID_RE = re.compile(r"""[ \t]*                    # optional whitespace
                       [#]{0,6}                  # end of heading
                       [ \t]*                    # optional whitespace
                       (?:[ \t]*[{\[][ \t]*(?P<type>[#.])(?P<id>[-._:a-zA-Z0-9 ]+)[}\]])
                       [ \t]*                    # optional whitespace
                       (\n|$)              #  ^^ group('id') = id attribute
                    """,
                    re.VERBOSE)

SECTIONLINK_PERMITTED_TAGS=set("h1 h2 h3 h4 h5 h6".split())
SECTIONLINK_CSS = r'''
/* The following code is added by mdx_elementid.py
   It was originally lifted from http://subversion.apache.org/style/site.css */
/*
 * Hide class="elementid-sectionlink", except when an enclosing heading
 * has the :hover property.
 */
.elementid-sectionlink {
  display: none;
}
'''

for tag in SECTIONLINK_PERMITTED_TAGS:
    SECTIONLINK_CSS += '''\
%s:hover > .elementid-sectionlink {
  display: inline;
}
''' % tag

class IdTreeProcessor(markdown.treeprocessors.Treeprocessor):
    """ Id Treeprocessor - parse text for id specs. """

    def _parseID(self, element):
        ''' recursively parse all {#idname}s at eol into ids '''
        if isBlockLevel(element.tag) and element.tag not in ['code', 'pre']:
            #print element
            if element.text and element.text.strip():
                m = ID_RE.search(element.text)
                if m:
                    if m.group('type') == '#':
                        element.set('id',m.group('id'))
                    else:
                        element.set('class',m.group('id'))
                    element.text = element.text[:m.start()]
                    # TODO: should this be restricted to <h1>..<h4> only?
                    if element.tag in SECTIONLINK_PERMITTED_TAGS:
                        child = etree.Element("a")
                        for k,v in {
                                      'class': 'elementid-sectionlink',
                                      'href': '#'+m.group('id'),
                                      'title': 'Link to this section',
                                   }.iteritems():
                            child.set(k, v)
                        # child.text = r" ¶" # U+00B6 PILCROW SIGN
                        child.text = "&para;"

                        # Actually append the child, and a space before it too.
                        #element.append(child)
                        #if len(element):
                        #    element.text += " "
                        #else:
                        #    element[-1].tail += " "
            for e in element:
                self._parseID(e)
        return element
        

    def run(self, root):
        '''
        Find and remove all id specs references from the text,
        and add them as the id attribute of the element.
        
        ROOT is div#section_content.
        '''
        if isBlockLevel(root.tag) and root.tag not in ['code', 'pre']:
            self._parseID(root)
            child = etree.Element("style")
            for k,v in {
                          'type': 'text/css',
                       }.iteritems():
                child.set(k, v)
            # Note upstream doc bug: it's not called markdown.AtomicString().
            child.text = markdown.util.AtomicString(SECTIONLINK_CSS)
            #root.insert(0, child)
            # child.tail = root.text; root.text = None;
        return root

class IdExtension(markdown.Extension):
    """ Id Extension for Python-Markdown. """

    def extendMarkdown(self, md, md_globals):
        """ Insert IdTreeProcessor in tree processors. It should be before toc. """
        idext = IdTreeProcessor(md)
        idext.config = self.config
        md.treeprocessors.add("elid", idext, "_begin")


def makeExtension(configs=None):
    return IdExtension(configs=configs)

if __name__ == "__main__":
    import doctest
    doctest.testmod()
