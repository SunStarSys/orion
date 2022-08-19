# SunStar Systems CMS (Build Toolchain)

- TO BUILD A SITE:

```
   % ./markdownd.js &
   % time ./build_site.pl --source-base ../$(src_dir) --target-base ../$(target_dir)
```

## Obsoleted Python-Markdown-based build system

### This includes mdx_elementid.py support.

## New build system is based on node.js and Editor.md: markdownd.js!

### npm prerequisites: jquery, navigator, jsdom.

### markdownd.js ENV VARS: NODE_PATH, EDITOR_MD, and MARKDOWN_PORT.

### Enjoy: no more deltas between online editor previews and build system markdown rendering

# HOWTO

1. Create a source tree with the following layout:

   - trunk/
       - content/
       - cgi-bin/ (optional)
       - lib/
           - path.pm
           - view.pm
       - templates/

    See <https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com/> for a live example.

2. Launch the markdownd.js server in the background.

3. Run build_site.pl --source-base /path/to/sources/trunk --target-base /wherever/you/want

# Python 3.8 Port Plan

## Reuse /lib:

    - lib/
      - SunStarSys/
      - View.py (volunteers needed!)
      - Util.py (I will handle this)

    - build_file.py (volunteers?)
    - build_site.py (volunteers?)


## Site Build Developer API

    - lib/path.py:
      - NOT OO, only data structure population
      - path.patterns:
        - array of arrays:
          - outer array:
            - orders priority of pattern matches from first elt of inner arrays
            - falls back to SunStarSys.Util.copy_if_newer behavior
          - inner arrays:
            - pattern: regex to text source file's path against
            - view: method name in view class to invoke
            - args: dict of **args passed to view method in prior slot
      - path.dependencies:
        - dict of arrays:
        - keys are paths to sources rooted in source tree's "content" dir
        - values are array of similarly rooted files the key depends on

    - lib/view.py:
      - OO: view class should inherit from SunStarSys.View
      - defines class methods to be invoked by build script as follows <
        s = view.getattr(method, None)
        args[path] = path
        content, ext, args = s(**args)
