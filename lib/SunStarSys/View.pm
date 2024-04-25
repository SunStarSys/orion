package view;
package SunStarSys::View;

# abstract base class for default view methods
# see http://svn.apache.org/repos/asf/infrastructure/site/trunk/lib/view.pm for sample usage
# see http://svn.apache.org/repos/asf/thrift/cms-site/trunk/lib/view.pm for advanced usage
#
# newer features added in early 2014:
# * stacked wrapper views like 'offline' and 'memoize' that alter performance;
# * 'quick_deps' argument option to short-circuit full deps processing to either:
#   quick_deps => 1, the bare minimum, which just processes headers, should be tried first, or
#   quick_deps => 2, which keeps the content read off disk for processing too,
#   quick_deps => 3, which just takes the deps builds temporarily "offline", and hence is the
#                    most conservative of the three options;
# * 'snippet' wrapper view to preparse [snippet:arg1=val1:arg2=val2:...] template blocks;
# * new args like 'preprocess', 'deps' and 'conf' with custom behavior;
# * new wrapper views like 'reconstruct' and 'trim_local_links' that when combined with
#   'snippet', allow markdown files in source code repos to be imported to the website;
# * a more flexible 'sitemap' that takes a 'nest' argument to nest directory links into a tree

use utf8;
use strict;
use warnings;
use Dotiac::DTL qw/Template *TEMPLATE_DIRS/;
use Dotiac::DTL::Addon::markup;
use Dotiac::DTL::Addon::json;
use SunStarSys::Util qw/read_text_file sort_tables parse_filename sanitize_relative_path Dump Load touch/;
use Data::Dumper ();
use File::Basename;
use File::Path;
use IO::Compress::Gzip 'gzip';
use LWP::UserAgent;
use URI::Escape;
use SunStarSys::SVNUtil;
use POSIX qw/:locale_h/;
use locale;
use File::stat;
use List::Util qw/max/;
use File::Copy;
use Data::Dumper;
use base 'sealed';
use sealed;

our %LANG = (
  ".de" => "de_DE.UTF-8",
  ".en" => "en_US.UTF-8",
  ".es" => "es_ES.UTF-8",
  ".fr" => "fr_FR.UTF-8",
  ""    => "en_US.UTF-8",
);

$ENV{PATH} = "/usr/local/bin:/usr/local/texlive/2023/bin/x86_64-solaris:/usr/bin:/bin";
$ENV{LANG} = "en_US.UTF-8";
$ENV{DISPLAY} = ":0";

our $URIc     = '^:/?=&;#A-Za-z0-9.~_-';        # complement of class of characters to uri_escape

push our @TEMPLATE_DIRS, "templates";
our $VERSION = "3.00";

# This is most widely used view.  It takes a 'template' argument and a 'path' argument.
# Assuming the path ends in foo.mdtext, any files like foo.page/bar.mdtext will be parsed and
# passed to the template in the "bar" (hash) variable.
#
# Now supports templating within the markdown sources.
# Pass this a true 'preprocess' arg to enable template preprocessing of markdown sources...
# 'deps' arrayref and 'conf' arguments have special behavior (passed to foo.page/bar.mdtext)
#
#
#

sub single_narrative :Sealed {
  my %args = @_;
  my $path = $args{path};
  my $file = "content$args{path}";
  my $template = $args{template};
  $args{deps} //= {};

  read_text_file $file, \%args unless exists $args{content} and exists $args{headers};
  setlocale $_, $LANG{$args{lang}} for LC_ALL;
  $template = $args{headers}{template} if exists $args{headers}{template};

  my view $view;
  my @new_sources = $view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});
  $args{breadcrumbs} = $view->can("breadcrumbs")->($args{path}, $args{lang});

  utf8::decode $args{path};

  my @closed = split /\s*[;,]\s*/, $args{headers}{closed} // "";
  my @muted = split /\s*[;,]\s*/, $args{headers}{muted} // "";
  my @important = split /\s*[;,]\s*/, $args{headers}{important} // "";

  my $page_path = $file;
  $page_path =~ s!\.[^/]+$!.page!;
  my $root = basename $page_path;
  if (-d $page_path) {
    for my $f (grep -f, glob "'$page_path/'*") {
      if ($f =~ m!/([^/]+)\.md(?:text)?\Q$args{lang}\E$!) {
        my $key = $1;
        $args{$key} = {};
        read_text_file $f, $args{$key};
        $args{$key}->{key} = $key;
        $args{$key}->{facts} = $args{facts} if exists $args{facts};
        $args{$key}->{deps} = $args{deps} if exists $args{deps};
        $args{$key}->{content} = sort_tables($args{preprocess}
                                               ? Template($args{$key}->{content})->render($args{$key})
                                               : $args{$key}->{content});
        if (index($key, "comment") == 0) {
          for my $c (@closed) {
            ++$args{$key}{closed} and last if index($key, $c) == 0;
          }
          for my $m (@muted) {
            ++$args{$key}{muted} and last if index($key, $m) == 0;
          }
          for my $i (@important) {
            ++$args{$key}{important} and last if $key eq $i;
          }
          push @{$args{comments}}, $args{$key};
        }
      }
      elsif ($f =~ m!/([^/]+)\.(?:ya?ml|json)\Q$args{lang}\E$!) {
        my $key = $1;
        $args{$key} = {};
        read_text_file $f, $args{$key};
        utf8::encode $args{$key}{content};
        $args{$key}{content} = Load $args{$key}{content};
      }
      elsif ($f !~ /(?:\.html\b|\.md\b|\.asy\b)[^\/]*$/) {
        push @{$args{attachments}}, "$root/" . basename $f;
      }
    }
  }

  # only include parallel deps (from globs in the Dependencies header)
  my $dir = $args{deps_root} // dirname($path);
  $args{deps} = [grep {index(dirname($_->[0]), $dir)==0} @{$args{deps}}];

  if ($args{preprocess}) {
    $args{content} = sort_tables(Template($args{content})->render(\%args));
  }
  else {
    $args{content} = sort_tables($args{content});
  }

  my ($filename, $directory, $ext) = parse_filename $file;
  s/^[^.]+// for my $lang = $ext;
  my $args_headers;
  my Data::Dumper $d;
  $d = $d->new([$args{headers}], ['$args_headers']);
  $d->Deepcopy(1);
  $d->Purity(1);
  eval $d->Dump;

  utf8::downgrade $_ for grep defined, map ref($_) eq "HASH" ? values %$_ : ref($_) eq "ARRAY" ? @$_ : $_, values %$args_headers;

  my $headers = Dump $args_headers;
  my $categories = delete $$args_headers{categories};
  my $status = delete $$args_headers{status} // "draft";
  my $archive_headers = Dump $args_headers;
  my $keywords = $args{headers}{keywords};

  utf8::decode $_ for grep defined, $archive_headers, $headers, $categories, $status, $keywords;

  if (exists $args{archive_root}
      and exists $args{headers}
      and defined $status
      and lc($status) eq "archived"
      and $args{mtime}) {

    my ($mon, $year) = (gmtime $args{mtime})[4,5];
    $mon = sprintf "%02d", $mon + 1;
    $year += 1900;
    $args{archive_path} = "$args{archive_root}/$year/$mon";

    my $archive_dir = "content$args{archive_path}";
    my $f = "$archive_dir/$filename.$ext";
    unless (-f $f) {
      mkpath $archive_dir;
      unlink glob("$archive_dir/../../*/*/$filename.$ext");
      open my $fh, ">:encoding(UTF-8)", $f
        or die "Can't archive $path to $f: $!\n";
      print $fh <<EOT;
$archive_headers
---
{% ssi \`$path\` %}
EOT
      push @new_sources, $f;
    }
    for my $f (grep {utf8::encode($_), not -f} "$archive_dir/index.html$lang", dirname($archive_dir)."/index.html$lang") {
      open my $fh, ">:encoding(UTF-8)", $f
        or die "Can't open archive to $f: $!\n";
      my $type = $f eq "$archive_dir/index.html$lang" ? "year" : "month";
      print $fh <<EOT;
{% include "$type.html" %}
EOT
      push @new_sources, $f;
    }
  }

  $categories = [sort $categories =~ /(\b[\w\s-]+\b)/g] if defined($categories) and not ref $categories;
  $keywords = [sort split /[;,]\s*/, $keywords] if defined($keywords) and not ref $keywords;
  undef $categories if $filename eq "index"; #index files are forbidden from categorization (conflicts w/ below index.html$lang setup)

  if (exists $args{category_root}
      and exists $args{headers}
      and defined $categories) {

    my $category_root = "content$args{category_root}";

    for my $cat (@{$categories}) {
      my $f = "$category_root/$cat/$filename.$ext";
      utf8::encode $f;
      unless (-f $f) {
        local $_ = "$category_root/$cat";
        utf8::encode $_;
        mkpath $_;
        open my $fh, ">:encoding(UTF-8)", $f
          or die "Can't categorize $path to $f: $!\n";
        print $fh <<EOT;
$headers
---

{% ssi \`$path\` %}
EOT
        push @new_sources, $f;
      }

      for my $f (grep {utf8::encode($_); not -f} "$category_root/$cat/index.html$lang") {
        open my $fh, ">:encoding(UTF-8)", $f
          or die "Can't categorize $f: $!\n";
        print $fh <<EOT;
{% include "category.html" %}
EOT
        push @new_sources, $f;
      }
    }
  }

  $args{headers}{categories} = $categories if defined $categories;
  $args{headers}{keywords}   = $keywords   if defined $keywords;

  $_ .= "/$filename.html$lang" for grep defined, $args{archive_path};
  my @rv = (Template($template)->render(\%args), html => \%args, @new_sources);
  setlocale $_, $LANG{".en"} for LC_ALL;
  return @rv;
}

sub asymptote {
  my %args = @_;
  my $lang = $args{lang};
  my $page_path = "content$args{path}";
  my ($base) = parse_filename $page_path;
  my $attachments_dir = dirname($page_path) . "/$base.page";
  read_text_file $page_path, \%args unless exists $args{content} and exists $args{headers};
  my $prefix = "asyA";
  my @sources;
  $args{content} =~ s{^\`{3}asy(?:mptote)?\s+(.*?)^\`{3}$}{
    s/^\s+settings.*\n//msg for my $body = $1;
    my $cached = 0;
    -d $attachments_dir or do { local $_ = $attachments_dir; utf8::encode $_; mkpath $_ };
    my $file = "$attachments_dir/$prefix";
    if (-f "$file.asy$lang" and open my $fh, "<:encoding(UTF-8)", "$file.asy$lang") {
      read $fh, my $content, -s $fh;
      if ($content eq $body) {
        ++$cached;
      }
    }
    unless ($cached) {
      open my $fh, ">:encoding(UTF-8)", "$file.asy$lang" or die "Can't open '$file.asy$lang' for writing: $!";
      print $fh $body;
      close $fh;
      #push @sources, "$file.asy$lang";
      system "time asy -f html -o '$file' '$file.asy$lang'" and die "asy html rendering of '$prefix' failed: $?";
      rename "$file.html", "$file.html$lang";
      #push @sources, "$file.html$lang";
    }
    my $rv = qq(\n<iframe id="$prefix" loading="lazy" class="asymptote" src="$base.page/$prefix.html$lang" frameborder="0"></iframe>\n);
    ++$prefix;
    $rv;
  }msge;
  my $view = next_view(\%args);
  return view->can($view)->(%args), @sources;
}

# Typical multi-narrative page view.  Has the same behavior as the above for foo.page/bar.mdtext
# files, parsing them into a bar variable for the template.
#
# Otherwise presumes the template is the path and any input content was generated in a wrapper.
# pass a true 'preprocess' arg for template preprocessing of content in foo.page/bar.mdtext files
# 'deps' arrayref and 'conf' args are passed along to foo.page/bar.mdtext files

sub news_page {
  my %args = @_;
  my $page_path = "content$args{path}";
  my $template = $args{content} // $page_path;
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path}, $args{lang});
  $args{deps} //= {};

  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  $page_path =~ s!\.[^./]+$!.page!;
  if (-d $page_path) {
    for my $f (grep -f, glob "$page_path/*.{mdtext,md}") {
      $f =~ m!/([^/]+)\.md(?:text)?$! or die "Bad filename: $f\n";
      my $key = $1;
      $args{$key} = {};
      read_text_file $f, $args{$1};
      $args{$key}->{conf} = $args{conf} if exists $args{conf};
      $args{$key}->{deps} = $args{deps} if exists $args{deps};
      $args{$key}->{content} = sort_tables($args{preprocess}
                                   ? Template($args{$key}->{content})->render($args{$key})
                                   : $args{$key}->{content});
    }
  }

  # the extra (3rd) return value is for sitemap support
  return Template($template)->render(\%args), html => \%args, @new_sources;
}

# overridable internal sub for computing deps
# pass quick setting in 3rd argument to speed things up: 1 is faster than 2 or 3, but 3
# is guaranteed to work in 99.9% of all project builds.

sub fetch_deps {
  my ($path, $data, $quick) = @_;
  $quick //= 2;
  my @new_sources;
  no strict 'refs';
  my $dependencies = eval '*path::dependencies{HASH}';
  my $patterns = eval '*path::patterns{ARRAY}';

  for (@{$$dependencies{$path}}) {
    my $file = $_;
    next if exists $data->{$file};
    my ($filename, $dirname, $extension) = parse_filename $file;
    s/^[^.]+// for my $lang = $extension;
    for my $p (@$patterns) {
      my ($re, $method, $args) = @$p;
      next unless $file =~ $re;
      if ($args->{headers}) {
        my $d = Data::Dumper->new([$args->{headers}], ['$args->{headers}']);
        $d->Deepcopy(1)->Purity(1);
        eval $d->Dump;
      }
      if ($quick == 1 or $quick == 2) {
        $file = "$dirname$filename.html$lang";
        #$file .= ".gz" if $$args{compress};
        $data->{$file} = { path => $file, lang => $lang, %$args };
        # just read the headers for $quick == 1
        read_text_file "content$_", $data->{$file}, $quick == 1 ? 0 : undef;
      }
      else {
        local $SunStarSys::Value::Offline = 1 if $quick == 3;
        my $s = view->can($method) or die "Can't locate method: $method\n";
        # quick_deps set to 2 to avoid infinite recursion on cyclic dependency graph
        my (undef, $ext, $vars, @ns) = $s->(path => $file, lang => $lang, %$args, quick_deps => 2);
        $file = "$dirname$filename.$ext$lang";
        #$file .= ".gz" if $$args{compress};
        $data->{$file} = $vars;
        push @new_sources, @ns;
      }
      last;
    }
    $data->{$file}{headers}{title} //= ucfirst $filename;
  }
  my @d;
  while (my ($k, $v) = each %$data) {
    utf8::decode $k;
    push @d, [$k, $v] unless $k =~ m#\.page/#; # skip attachments
  }
  no warnings 'uninitialized'; # peculiar: should only happen with quick_deps>2
  # transform second argument to fetch_deps() from a hashref to an arrayref
  $_[1] = [sort {$b->[1]{mtime} <=> $a->[1]{mtime} or $a->[0] cmp $b->[0]} @d];

  return @new_sources;
}

# presumes the dependencies are all markdown files with subheadings of the form
## foo ## {#bar} or
## foo ## [#bar]
# useful for generating index.html pages as well given a suitably restricted set of dependencies
# pass a true 'nest' arg to nest links
# ditto for 'preprocess' arg to preprocess content with a Template() pass
# takes a 'deps' hashref to override deps fetching

my %title = (
  index => {
    en => "Index of ",
    es => "Índice de ",
    de => "Index von ",
    fr => "Indice de ",
  },
  sitemap => {
    en => "Sitemap of ",
    es => "Mapa del sitio de ",
    de => "Seitenverzeichnis von ",
    fr => "Plan du site de ",
  }
);

my %month = (
  en => [qw/0 January February March April May June July August September October November December/],
  es => [qw/0 enero febrero marzo abril mayo junio julio agostp  septiembre octubre noviembre diciembre/],
  de => [qw/0 Januar Februrar März April Mai Juni Juli August September Oktober November Dezember/],
  fr => [qw/0 janvier février mars avril mai juin juillet août septembre octobre novembre décembre/]
);

sub sitemap {
  my %args = @_;
  my $template = "content$args{path}";
  setlocale $_, $LANG{$args{lang}} for LC_ALL;
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path}, $args{lang});
  $args{deps} //= {};
  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  my $content = "";
  utf8::decode $args{path};
  my ($filename, $dirname, $extension) = parse_filename $args{path};
  s/^[^.]+\.// for my $lang = $extension;
  if ($args{path} =~ m!/(index|sitemap)\b[^/]*$!) {
    $args{headers}{title} //= $title{$1}{$lang}
      . ($dirname =~ m#/20\d{2}/(\d{2})/$#
                 ? $month{$lang}[$1] : ucfirst basename $dirname);
  }

  for (grep shift @$_, sort {$a->[0] cmp $b->[0]} map {s!/index\.html\b[^/]*$!/! for my $path = $_->[0]; [$path, @$_]} @{$args{deps}}) {
    no locale;
    my $title = $$_[1]{headers}{title};
    my ($lede) = ($$_[1]{content} // "") =~ /\Q{# lede #}\E(.*?)\Q{# lede #}\E/;
    $lede //= "";
    $lede =~ y/\n/ /, $lede = " &mdash; $lede..." if $lede;
    my ($filename, $dirname) = parse_filename $$_[0];
    if ($$_[0] =~ m!/(index|sitemap|$)[^/]*$! and $title eq ucfirst($1 || "index")) {
      $title = $title{+($1 || "index")}{$lang}
      . ($dirname =~ m#/20\d{2}/(\d{2})/$#
                 ? $month{$lang}[$1] : ucfirst basename $dirname);
    }
    $content .= "- [$title](" . uri_escape_utf8($$_[0], $URIc) . ")$lede\n\n";
  }

  if ($args{nest}) {
    no locale;
    1 while $content =~ s{^(\s*-\s)                  # \1, prefix
              (                                      # \2, link
                  \[ [^\]]+ \]
                  \(
                  (  [^\)]* / ) index\.html\b[\%\w.-]* # \3, (dir with trailing slash)
                  \)[^\n]*
              )
              (                                      # \4, subpaths
                  (?:\n\n\1\[ [^\]]+ \]\( \3 (?!index\.html\b[\%\w.-]*)[^\#?] .*)+
              )
       }{
         my ($prefix, $link, $subpaths) = ($1, $2, $4);
         $subpaths =~ s/\n\n/\n\n    /g;
         "$prefix$link$subpaths"
       }xme;
  }

  $args{content} = $args{preprocess} ? Template($content)->render(\%args) : $content;

  # the extra (3rd) return value is for sitemap support
  my @rv = (Template($template)->render(\%args), html => \%args, @new_sources);
  setlocale $_, $LANG{".en"} for LC_ALL;
  return @rv;
}

# internal utility sub for the wrapper views that follow (not overrideable)

sub next_view {
  my $args = pop;
  $args->{view} = [@{$args->{view}}] if ref $args->{view}; # copy it since we're changing it
  return ref $args->{view} && @{$args->{view}} ? shift @{$args->{view}} : delete $args->{view};
}

sub langify_template {
  my %args = @_;
  my (undef, undef, $extension) = parse_filename $args{path};
  s/^[^.]+\.// for my $lang = $extension;
  %args{template} .= ".$lang" if defined %args{template};
  my $view = next_view(\%args);
  return view->can($view)->(%args);
}

sub skip {
  my %args = @_;
  my ($prefix, $dir, $ext) = parse_filename "content$args{path}";
  $args{ext} //= "tex";
  s/^([^.]*)//, $ext = $1 for my $lang = $ext;

  if ($ext eq "bib") {
    # generate yaml bibliography database
    read_text_file "content$args{path}", \%args;
    my $attachments_dir = "$dir$prefix.page";
    -d $attachments_dir or do { local $_ = $attachments_dir; utf8::encode $_; mkpath $_ };
    my @entries;
    for ($args{content}) {
      while (/^@(\w+)\{(\w+),\n(.*?)\n\}/msg) {
        my ($type, $id, $innards, %attrs) = ($1, $2, $3);
        $attrs{$1} = $2 while $innards =~ /(\w+)\s*=\s*\{(.*?)\}/g;
        $attrs{id} = $id;
        $attrs{type} = $type;
        push @entries, \%attrs;
      }
    }
    open my $fh, ">:raw", my $fname = "$attachments_dir/bibliography.yml$lang" or die "Can't open bibliography.yml$lang in $attachments_dir: $!";
    print $fh "---\ntitle: Bibliography\nstatus: generated\ndependencies: ../$prefix.$ext$lang\n";
    print $fh Dump \@entries;
  }

  return undef, skip => \%args;
}

sub yml2ext {
  my %args = @_;
  my $path = "content$args{path}";
  my $filter = $args{filter} // "json_raw";
  read_text_file $path, \%args unless exists $args{content} and defined $args{headers};
  my $template = $args{template} // '{{content|' . $filter . '|safe}}';
  utf8::encode $args{content};
  $args{content} = Load $args{content};
  return Template($template)->render(\%args), $args{ext} // "json", \%args;
}


# build pdfs from latex

sub latexmk {
  my %args = @_;
  my $file = "content$args{path}";
  my ($base, $dir, $ext) = parse_filename $file;
  s/^([^.]*)//, $ext = $1 for my $lang = $ext;
  read_text_file $file, \%args unless exists $args{content} and defined $args{headers};
  my $cache_file = "$ENV{TARGET_BASE}/$dir$base.$ext$lang";
  my $cached = 0;
  my $generator = $args{generator} // "xelatex";
  my $bib_mtime = max 0, map {(-f $_) ? File::stat::populate(CORE::stat(_))->mtime : ()} $args{content} =~ /^\\addbibresource\{(.*?)\}/mg;

  if (-f $cache_file and open my $fh, "<:encoding(UTF-8)", $cache_file) {
    read $fh, my $content, -s $fh;
    if ($content eq $args{content} and $args{mtime} >= $bib_mtime) {
      ++$cached;
    }
    elsif (-f "$ENV{TARGET_BASE}/$dir$base.bbl$lang" and $bib_mtime < File::stat::populate(CORE::stat(_))->mtime) {
      copy "$ENV{TARGET_BASE}/$dir$base.bbl$lang", "/tmp/$base.$ext.bbl";
    }
  }

  if (not $cached and -f $file and my $status = system "latexmk -pdfxe -pdfxelatex=$generator -auxdir=/tmp '$file'") {
    unlink </tmp/$base.$ext*>, <*.{out,tex,pre,aux,ps,pdf,prc,log}>;
    die "latexmk -$args{format} rendering of '$file' failed: ". ($status>>8);
  }
  syswrite STDOUT, "Copied to $cache_file.\n"; # internal copy, deletions need this notice to track it
  ($cached or move "/tmp/$base.$ext.bbl", "$ENV{TARGET_BASE}/$dir$base.bbl$lang") and
    syswrite STDOUT, "Copied to $ENV{TARGET_BASE}/$dir/$base.bbl$lang.\n"; # another internal copy

  return undef, $args{format} => \%args if $cached;

  touch $file;

  move "$base.$ext.$args{format}", "$ENV{TARGET_BASE}/$dir$base.$args{format}$lang";
  unlink </tmp/$base.$ext*>, <*.{out,tex,pre,aux,ps,pdf,prc,log}>;
  open my $fh, ">:encoding(UTF-8)", $cache_file or die "Can't write to '$cache_file': $!";
  print $fh $args{content};
  close $fh;
  return undef, $args{format} => \%args;
}

# recursively evaluates ssi tags in content

sub ssi {
  my %args = @_;
  my $file = "content$args{path}";
  read_text_file $file, \%args unless defined $args{headers} and defined $args{content};

  my @closed = split /\s*[;,]\s*/, $args{headers}{closed} // "";
  my @muted = split /\s*[;,]\s*/, $args{headers}{muted} // "";
  my @important = split /\s*[;,]\s*/, $args{headers}{important} // "";

  1 while $args{content} =~ s{(\{%\s*ssi\s+\`([^\`]+)\`\s*%\})}{
    my $match = $1;
    my $target = $2;
    my $page_path = "content$target";
    read_text_file $page_path, \my %a;
    $args{headers} = $a{headers};
    $page_path =~ s!\.[^/]+$!.page!;
    my $root = basename $page_path;
    if (-d $page_path) {
      for my $f (grep -f, glob "'$page_path/'*") {
        if ($f =~ m!/([^/]+)\.md(?:text)?\Q$args{lang}\E$!) {
          my $key = $1;
          $args{$key} = {};
          read_text_file $f, $args{$key};
          $args{$key}->{key} = $key;
          $args{$key}->{facts} = $args{facts} if exists $args{facts};
          $args{$key}->{deps} = $args{deps} if exists $args{deps};
          $args{$key}->{content} = sort_tables($args{preprocess}
                                                 ? Template($args{$key}->{content})->render($args{$key})
                                                 : $args{$key}->{content});
          if (index($key, "comment") == 0) {
            for my $c (@closed) {
              ++$args{$key}{closed} and last if index($key, $c) == 0;
            }
            for my $m (@muted) {
              ++$args{$key}{muted} and last if index($key, $m) == 0;
            }
            for my $i (@important) {
              ++$args{$key}{important} and last if $key eq $i;
            }
            push @{$args{comments}}, $args{$key};
          }
        }
        elsif ($f =~ m!/([^/]+)\.(?:ya?ml|json)\Q$args{lang}\E$!) {
          my $key = $1;
          $args{$key} = {};
          read_text_file $f, $args{$key};
          utf8::encode $args{$key}{content};
          $args{$key}{content} = Load $args{$key}{content};
        }
        elsif ($f !~ /(?:\.html\b|\.md\b|\.asy\b)[^\/]*$/) {
          push @{$args{attachments}}, "$root/" . basename $f;
        }
      }
    }
    Template($match)->render({})
  }ge;
  my $view = next_view \%args;
  return view->can($view)->(%args);
}

# wrapper view for creating final content (eg sitemaps) that doesn't require being online
# to service relevant content generation in dependencies, etc.

sub offline {
  local $SunStarSys::Value::Offline = 1;
  my %args = @_;
  my $view = next_view \%args;
  return view->can($view)->(%args);
}

# see top of www.apache.org site for how this works in practice (drops filename,
# just provides dirs).  overridable internal sub

sub breadcrumbs {
  my $src = shift;
  my $lang = shift;
  utf8::decode $src;
  my @path = split m!/!, $src;
  pop @path;
  my @rv;
  my $abspath = "";
  for (@path) {
      $abspath .= "$_/";
      $_ ||= "Home";
      push @rv, qq(<a href="${abspath}index.html$lang">\u$_</a>);
  }
  return join "&nbsp;&raquo;&nbsp;", @rv;
}

# Extensive use of the memoize() wrapper view probably necessitates adding
#
# our $runners = 1;
#
# in lib/path.pm to get the full benefit of the cache. That will ensure that site builds are
# processed by the same child perl process.  Use of this feature is a trial and error balancing
# process of performance behavior because by default 8 child 'runners' will process the site
# build in parallel, and reducing that number will tend to counteract the performance gains of
# caching built pages in sites with complex dependencies.
#
# mostly unnecessary outside of "quick_deps > 2", given how
# SunStarSys::Util::read_text_file's cache does the heavy lift
# at lib/path.pm load time during walk_content_tree {}.


{
  my %cache;

  sub memoize {
    my %args = @_;
    my $view = next_view \%args;
    my $file = "content$args{path}";
    return @{$cache{$file}} if exists $cache{$file};

    return view->can($view)->(%args) if $SunStarSys::Value::Offline; # don't cache offline pages

    $cache{$file} = [ view->can($view)->(%args) ];
    return @{$cache{$file}};
  }

  sub flush_memoize_cache {
    %cache = ();
  }
}

sub compress {
  my %args = @_;
  my $view = next_view \%args;
  my @rv = view->can($view)->(%args);
  utf8::encode($rv[0]);
  gzip \($rv[0], my $compressed);
  return $compressed, "$rv[1].gz", @rv[2..$#rv];
}

# wrapper view for pulling snippets out of code repos; see thrift site sources for sample usage
# 'snippet_footer' and 'snippet_header' args are supported.

sub snippet {
  my %args = @_;
  my $file = "content$args{path}";
  read_text_file $file, \%args unless exists $args{headers} and exists $args{content};
  my $key = "snippetA";
  no warnings 'uninitialized';
  $args{content} =~ s{\[snippet:([^\]]+)\]} # format is [snippet:arg1=val1:arg2=val2:...]
                     {
                         my $argspec = $1;
                         my %a = (%args, map {split /=/, $_, 2} split /:/, $argspec);
                         require SunStarSys::Value::Snippet; # see source for list of valid args
                         $args{$key} = SunStarSys::Value::Snippet->new(%a);
                         my $linenums = $a{numbers} ? "linenums" : "";
                         my $filter = exists $a{lang} ? "markdown" : "safe";
                         my $rv = <<EOT;

\`\`\`$a{lang}
{{ $key.fetch|safe }}
\`\`\`

EOT
                         if (defined(my $header = $args{snippet_header})) {
                           $header =~ s/\$snippet\b/$key/g;
                           $rv = "$header\n$rv";
                         }
                         if (defined(my $footer = $args{snippet_footer})) {
                           $footer =~ s/\$snippet\b/$key/g;
                           $rv .= "\n$footer";
                         }
                         ++$key;
                         $rv;
                     }ge;


  my $view = next_view \%args;
  return view->can($view)->(%args, preprocess => 1);
}

# wrapper view for rebuilding content and headers from content created in a prior wrapper
# will reread 'content' argument for any headers after a template pass (assuming 'preprocess'
# arg is set to enable that)

sub reconstruct {
  my %args = @_;
  die "Can't reconstruct from existing content" unless exists $args{content};
  read_text_file \( $args{preprocess}
                      ? Template($args{content})->render(\%args)
                      : $args{content},
                    %args );
  my $view = next_view \%args;
  delete $args{preprocess}; # avoid duplication of template processing
  view->can($view)->(%args);
}

# wrapper which drops file extensions from local links in markdown and html content.
# The reason this is a good thing is that all of the relevant httpd servers have MultiViews
# setup to dispatch to the correct file on the server's filesystem, so removing extensions
# (and trailing slashes) as a policy matter for links is wise.

sub trim_local_links {
  my %args = @_;
  my $view = next_view \%args;
  read_text_file "content$args{path}", \%args unless exists $args{content};

  no warnings 'uninitialized';
  $args{content} =~ s(                 # trim markdown links
                         \[
                         ( [^\]]+ )
                         \]
                         \(
                         ( (?!https?://|mailto://|\{)[^\)#?]*? ) (?:\.\w+|\/) ([#?][^\)#?]+)?
                         \)
                   )([$1]($2$3))gx;

  $args{content} =~ s(                 # trim html links
                         (<[^>]+(?:href|src))=(['"])
                         ( (?!https?://|mailto://|\{)[^'"?#]*? ) (?:\.\w+|\/) ([#?][^'"#?]+)?
                         \2
                     )($1=$2$3$4$2)gx;

  return view->can($view)->(%args);
}

sub normalize_links {
  my %args = @_;
  my $view = next_view \%args;
  read_text_file "content$args{path}", \%args unless exists $args{content};

  no warnings 'uninitialized';
  $args{content} =~ s{                 # trim markdown links
                         \[
                         ( [^\]]+ )
                         \]
                         \(
                         ( (?!https?://|mailto://|\{)[^\)#?]*? ) ([#?][^\)#?]+)?
                         \)
                     }{
                       my ($title, $url, $suffix) =($1, $2, $3);
                       $url =~ s!/\./!/!g;
                       $url =~ s/ /%20/g;
                       1 while $url =~ s#/[^/]+/\.\./#/#;
                       "[$title]($url$suffix)"
                     }gex;

  $args{content} =~ s{                 # trim html links
                         (<[^>]+(?:href|src))=(['"])
                         ( (?!https?://|mailto://|\{)[^'"?#]*? ) ([#?][^'"#?]+)?
                         \2
                     }{
                       my ($tag, $quote, $url, $suffix) = ($1, $2, $3, $4);
                       $url =~ s!/\./!/!g;
                       $url =~ s/ /%20/g;
                       1 while $url =~ s#/[^/]+/\.\./#/#;
                       "$tag=$quote$url$suffix$quote"
                     }gex;
  return view->can($view)->(%args);
}

1;

=head1 LICENSE

           Licensed to the Apache Software Foundation (ASF) under one
           or more contributor license agreements.  See the NOTICE file
           distributed with this work for additional information
           regarding copyright ownership.  The ASF licenses this file
           to you under the Apache License, Version 2.0 (the
           "License"); you may not use this file except in compliance
           with the License.  You may obtain a copy of the License at

             http://www.apache.org/licenses/LICENSE-2.0

           Unless required by applicable law or agreed to in writing,
           software distributed under the License is distributed on an
           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
           KIND, either express or implied.  See the License for the
           specific language governing permissions and limitations
           under the License.
