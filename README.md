# SunStar Systems' Orion&trade; Enterprise Wiki (SSG Build Toolchain)

## TO BUILD THE OpenOffice.Org SITE to ./www (at ~1 GB/s, or 50 μs/file, on modern hardware)

```shell
   % SVN_URL=https://svn.apache.org/repos/asf/openoffice/ooo-site ./test.sh
```

First time thru this will run forever, because the source tree in trunk needs
this patch:

```diff
Index: trunk/lib/view.pm
===================================================================
--- trunk/lib/view.pm (revision 1905280)
+++ trunk/lib/view.pm (working copy)
@@ -154,7 +154,7 @@
     my %args = @_;
     open my $fh, "content$args{path}" or die "Can't open $args{path}:$!";
     read $fh, my $content, -s $fh;
-    return $content, html => %args;
+    return $content, html => \%args;
 }

 sub breadcrumbs {
```

Compare with (content-trimmed-down) 60x slower JBake build port at <https://builds.apache.org/job/OpenOffice>.

### TO generate the link topology graph (SVGZ) for OpenOffice.Org, run

```shell
    % ./links2dotcfg.pl '^$' index ""
```
## Buildable text content should be UTF-8

## Perl prerequisites

- sealed v4.1.8
- IO::Select
- YAML::XS
- APR::Request (which has a build dependency on mod_perl)



### (IoC) Build API

Core Build Engine:

- provide `@path::patterns` in lib/path.pm
- provide `view code` in lib/view.pm (typically derived from `SunStarSys::View`)
- grok the associated API you need to conform to as expressed below

```perl
  ...

  my $path = "/path/to/source/file";

  for my $p (@path::patterns) {
    my ($re, $method, $args) = @$p;
    next unless $path =~ $re;
    ++$matched;

    my ($content, $mime_extension, $new_args, @new_sources) = view->can("$method")->(path => $path, lang => $lang, %$args);

... write UTF $content to target file with associated $mime_extension file-type
  }

  copy($path, "$target_base$path") unless $matched;

  ...

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

1. Launch the markdownd.js server in the background.
1. Run build_site.pl --source-base /path/to/sources/trunk --target-base /wherever/you/want

## Python 3.8 Port Plan

### Reuse /lib

```yaml
    - lib/
      - SunStarSys/
        - View.py (volunteers needed!)
        - Util.py (I will handle this)

    - build_file.py (volunteers?)
    - build_site.py (volunteers?)
```

### Site Build Developer API

```yaml
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
```

Markdown-based mermaid+mindmap rendering tests:

```mermaid
graph TD
    A[Christmas] -->|Get money| B(Go shopping)
    B --> C{Let me think}
    C -->|One| D[Laptop]
    C -->|Two| E[iPhone]
    C -->|Three| F[fa:fa-car Car]
```

```mermaid
sequenceDiagram
    participant Alice
    participant Bob
    Alice->>John: Hello John, how are you?
    loop Healthcheck
        John->>John: Fight against hypochondria
    end
    Note right of John: Rational thoughts<br/>prevail...
    John-->>Alice: Great!
    John->>Bob: How about you?
    Bob-->>John: Jolly good!
```
```mermaid
erDiagram
    CUSTOMER }|..|{ DELIVERY-ADDRESS : has
    CUSTOMER ||--o{ ORDER : places
    CUSTOMER ||--o{ INVOICE : "liable for"
    DELIVERY-ADDRESS ||--o{ ORDER : receives
    INVOICE ||--|{ ORDER : covers
    ORDER ||--|{ ORDER-ITEM : includes
    PRODUCT-CATEGORY ||--|{ PRODUCT : contains
    PRODUCT ||--o{ ORDER-ITEM : "ordered in"
```
```mermaid
stateDiagram-v2
    [*] --> Still
    Still --> [*]
    Still --> Moving
    Moving --> Still
    Moving --> Crash
    Crash --> [*]
```
```mermaid
gantt
    title A Gantt Diagram
    dateFormat  YYYY-MM-DD
    section Section
    A task           :a1, 2014-01-01, 30d
    Another task     :after a1  , 20d
    section Another
    Task in sec      :2014-01-12  , 12d
    another task      : 24d
```
```mermaid
pie title Commits to orion on GitHub
	"Sunday" : 4
	"Monday" : 5
	"Tuesday" : 7
  "Wednesday" : 3
```
```mermaid
classDiagram
    Animal <|-- Duck
    Animal <|-- Fish
    Animal <|-- Zebra
    Animal : +int age
    Animal : +String gender
    Animal: +isMammal()
    Animal: +mate()
    class Duck{
      +String beakColor
      +swim()
      +quack()
    }
    class Fish{
      -int sizeInFeet
      -canEat()
    }
    class Zebra{
      +bool is_wild
      +run()
    }
```
```mermaid
gitGraph
    commit
    commit
    branch develop
    checkout develop
    commit
    commit
    checkout main
    merge develop
    commit
    commit
```
```mermaid
%%{init:{"theme":"default"}}%%
graph TB
    sq[Square shape] --> ci((Circle shape))

    subgraph A
        od>Odd shape]-- Two line<br/>edge comment --> ro
        di{Diamond with <br/> line break} -.-> ro(Rounded<br>square<br>shape)
        di==>ro2(Rounded square shape)
    end

    %% Notice that no text in shape are added here instead that is appended further down
    e --> od3>Really long text with linebreak<br>in an Odd shape]

    %% Comments after double percent signs
    e((Inner / circle<br>and some odd <br>special characters)) --> f(,.?!+-*ز)

    cyr[Cyrillic]-->cyr2((Circle shape Начало));

     classDef green fill:#9f6,stroke:#333,stroke-width:2px;
     classDef orange fill:#f96,stroke:#333,stroke-width:4px;
     class sq,e green
     class di orange
```
```mermaid
mindmap
  root((mindmap))
    Origins
      Long history
      ::icon(fa fa-book)
      Popularisation
        British popular psychology author Tony Buzan
    Research
      On effectivness<br/>and features
      On Automatic creation
        Uses
            Creative techniques
            Strategic planning
            Argument mapping
    Tools
      Pen and paper
      Mermaid
```
```mermaid
journey
    title My working day
    section Go to work
      Make tea: 5: Me
      Go upstairs: 3: Me
      Do work: 1: Me, Cat
    section Go home
      Go downstairs: 5: Me
      Sit down: 3: Me
```
```mermaid
flowchart TB
classDef borderless stroke-width:0px
classDef darkBlue fill:#00008B, color:#fff
classDef brightBlue fill:#6082B6, color:#fff
classDef gray fill:#62524F, color:#fff
classDef gray2 fill:#4F625B, color:#fff

subgraph publicUser[ ]
    A1[[Public User<br/> Via REST API]]
    B1[Backend Services/<br/>frontend services]
end
class publicUser,A1 gray

subgraph authorizedUser[ ]
    A2[[Authorized User<br/> Via REST API]]
    B2[Backend Services/<br/>frontend services]
end
class authorizedUser,A2 darkBlue

subgraph booksSystem[ ]
    A3[[Books System]]
    B3[Allows interacting with book records]
end
class booksSystem,A3 brightBlue


publicUser--Reads records using-->booksSystem
authorizedUser--Reads and writes records using-->booksSystem

subgraph authorizationSystem[ ]
    A4[[Authorization System]]
    B4[Authorizes access to resources]
end

subgraph publisher1System[ ]
    A5[[Publisher 1 System]]
    B5[Gives details about books published by them]
end
subgraph publisher2System[ ]
    A6[[Publisher 2 System]]
    B6[Gives details about books published by them]
end
class authorizationSystem,A4,publisher1System,A5,publisher2System,A6 gray2

booksSystem--Accesses authorization details using-->authorizationSystem
booksSystem--Accesses publisher details using-->publisher1System
booksSystem--Accesses publisher details using-->publisher2System

class A1,A2,A3,A4,A5,A6,B1,B2,B3,B4,B5,B6 borderless

click A3 "https://github.com/csymapp/mermaid-c4-model/blob/master/containerDiagram.md" "booksSystem"
```
