![Linter](https://github.com/SunStarSys/orion/actions/workflows/linter.yml/badge.svg)
![OOo](https://github.com/SunStarSys/orion/actions/workflows/ooo-site.yml/badge.svg)
![Iconoclasts](https://github.com/SunStarSys/orion/actions/workflows/iconoclasts.yml/badge.svg)

<img width="200px" src="https://sunstarsys.com/images/sunstar-orion-symbol-linear?github">

# SunStar Systems' Orion&trade; Enterprise Wiki (SSG Build Toolchain)

## Prerequisites

- docker
- 8 CPU
- 16GB RAM

## TO BUILD THE www.iconoclasts.blog SITE to ./www

```shell
   % ./test.sh
```

## TO BUILD SOME OTHER GIT-BACKED SITE from ./trunk to ./www

```shell

   % rm -rf trunk www
   % GIT_URL=https://github.com/FOO/BAR ./test.sh

```

## TO REVIEW THE BUILT ./www SITE UNDER APACHE2 on localhost:8000

```shell
  % LAUNCH_APACHE2=1 ./test.sh
```

### TO generate the link topology graph (SVGZ), run

```shell
    % ./links2dotcfg.sh '^$' index ""
```

### TO generate the content dependency graph (SVGZ), run

```shell
    % ./deps2dotcfg.pl '^$' index ""
```

## Buildable text content should be UTF-8

## USAGE

```shell
% ./test.sh
% ./test.sh ooo
% ./test.sh
% LAUNCH_APACHE2=1 ./test.sh
```

### (IoC) Build API

Core Build Engine:

- provide `@path::patterns` in lib/path.pm
- provide `view code` in lib/view.pm (typically derived from `SunStarSys::View`)
- grok the associated API you need to conform to as expressed below

```perl
#api
  ...

  my $path = "/path/to/source/file";

  for my $p (@path::patterns) {
    my ($re, $method, $args) = @$p;
    next unless $path =~ $re;
    ++$matched;

    my ($content, $mime_extension, $final_args, @new_sources) = view->can($method)->(path => $path, lang => $lang, %$args);

... write UTF $content to target file with associated $mime_extension file-type
  }

  copy($path, "$target_base/content$path") unless $matched;

  ...
#api
```

## HOWTO

### Create a source tree with the following layout

```yaml
   - trunk/
       - content/
       - cgi-bin/ (optional)
       - lib/
           - path.pm
           - view.pm
       - templates/
```

### [Site Build Developer API](https://sunstarsys.com/orion/api/build)

```yaml
    - lib/path.pm:
      - NOT OO, only data structure population
      - @path::patterns:
        - array of arrays:
          - outer array:
            - orders priority of pattern matches from first elt of inner arrays
            - falls back to SunStarSys::Util::copy_if_newer behavior
          - inner arrays:
            - pattern: regex to text source file's path against
            - view: method name in view class to invoke
            - args: dict of **args passed to view method in prior slot
      - %path::dependencies:
        - dict of arrays:
          - keys are paths to sources rooted in source tree's "content" dir
          - values are array of similarly rooted files the key depends on
      - @path::acl
        - array of hashes:
          - rules
          - path

    - lib/view.pm:
      - OO: view class should inherit from SunStarSys::View
```
