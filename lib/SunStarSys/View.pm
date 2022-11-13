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
use SunStarSys::Util qw/read_text_file sort_tables parse_filename Dump/;
use Data::Dumper ();
use File::Basename;
use File::Path;

push our @TEMPLATE_DIRS, "templates";
our $VERSION = "2.02";

# This is most widely used view.  It takes a 'template' argument and a 'path' argument.
# Assuming the path ends in foo.mdtext, any files like foo.page/bar.mdtext will be parsed and
# passed to the template in the "bar" (hash) variable.
#
# Now supports templating within the markdown sources.
# Pass this a true 'preprocess' arg to enable template preprocessing of markdown sources...
# 'deps' arrayref and 'conf' arguments have special behavior (passed to foo.page/bar.mdtext)

sub single_narrative {
  my %args = @_;
  my $path = $args{path};
  my $file = "content$args{path}";
  my $template = $args{template};
  $args{deps} //= {};

  read_text_file $file, \%args unless exists $args{content} and exists $args{headers};

  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  $args{path} =~ s!\.[^.]+(?=[^/]+$)!\.html!;
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path});

  my $page_path = $file;
  $page_path =~ s!\.[^./]+$!.page!;
  if (-d $page_path) {
    for my $f (grep -f, glob "$page_path/*.{mdtext,md}") {
      $f =~ m!/([^/]+)\.md(?:text)?$! or die "Bad filename: $f\n";
      $args{$1} = {};
      read_text_file $f, $args{$1};
      $args{$1}->{conf} = $args{conf} if exists $args{conf};
      $args{$1}->{deps} = $args{deps} if exists $args{deps};
      $args{$1}->{content} = sort_tables($args{preprocess}
                                  ? Template($args{$1}->{content})->render($args{$1})
                                  : $args{$1}->{content});
    }
  }

  # only include parallel deps (from globs in the Dependencies header)
  my $dir = dirname $path;
  $args{deps} = [grep {$dir eq dirname $_->[0]} @{$args{deps}}];

  $args{content} = sort_tables($args{preprocess}
                                   ? Template($args{content})->render(\%args)
                                   : $args{content});
  my ($filename, $directory, $ext) = parse_filename $file;
  my $archive = delete $args{headers}{archive};
  my $headers = Dump $args{headers};

  if (exists $args{archive_root}
      and exists $args{headers}
      and defined $archive
      and $args{mtime}) {

    my ($mon, $year) = (gmtime $args{mtime})[4,5];
    $mon = sprintf "%02d", $mon + 1;
    $year += 1900;

    my $archive_dir = "content$args{archive_root}/$year/$mon";
    my $f = "$archive_dir/$filename.$ext";
    unless (-f $f) {
      mkpath $archive_dir;
      unlink glob("$archive_dir/../../*/*/$filename.$ext");
      open my $fh, ">:encoding(UTF-8)", $f
        or die "Can't archive $path to $f: $!\n";
      print $fh <<EOT;
$headers
---
{% ssi \`$path\` %}
EOT
      push @new_sources, $f;
    }
  }

  if (exists $args{category_root}
      and exists $args{headers}
      and exists $args{headers}{categories}) {

    $args{headers}{categories} = [split /[;,]\s+/, $args{headers}{categories}] unless ref $args{headers}{categories};
    my $category_root = "content$args{category_root}";

    for my $cat (@{$args{headers}{categories}}) {
      next if -f (my $f = "$category_root/$cat/$filename.$ext");
      mkpath "$category_root/$cat";
      open my $fh, ">:encoding(UTF-8)", $f
        or die "Can't categorize $path to $f: $!\n";
      print $fh <<EOT;
$headers
---
{% ssi \`$path\` %}
EOT
      push @new_sources, $f;
    }
  }

  $args{headers}{archive} = $archive if defined $archive;
  return Template($template)->render(\%args), html => \%args, @new_sources;
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
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path});
  $args{deps} //= {};

  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  $page_path =~ s!\.[^./]+$!.page!;
  if (-d $page_path) {
    for my $f (grep -f, glob "$page_path/*.{mdtext,md}") {
      $f =~ m!/([^/]+)\.md(?:text)?$! or die "Bad filename: $f\n";
      $args{$1} = {};
      read_text_file $f, $args{$1};
      $args{$1}->{conf} = $args{conf} if exists $args{conf};
      $args{$1}->{deps} = $args{deps} if exists $args{deps};
      $args{$1}->{content} = sort_tables($args{preprocess}
                                   ? Template($args{$1}->{content})->render($args{$1})
                                   : $args{$1}->{content});
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

  for (@{${'path::dependencies'}{$path}}) {
    my $file = $_;
    next if exists $data->{$file};
    my ($filename, $dirname, $extension) = parse_filename;
    s/^[^.]+// for my $lang = $extension;
    for my $p (@{'path::patterns'}) {
      my ($re, $method, $args) = @$p;
      next unless $file =~ $re;
      if ($args->{headers}) {
        my $d = Data::Dumper->new([$args->{headers}], ['$args->{headers}']);
        $d->Deepcopy(1)->Purity(1);
        eval $d->Dump;
      }
      if ($quick == 1 or $quick == 2) {
        $file = "$dirname$filename.html$lang";
        $data->{$file} = { path => $file, lang => $lang, %$args };
        # just read the headers for $quick == 1
        read_text_file "content/$_", $data->{$file}, $quick == 1 ? 0 : undef;
      }
      else {
        local $SunStarSys::Value::Offline = 1 if $quick == 3;
        my $s = view->can($method) or die "Can't locate method: $method\n";
        # quick_deps set to 2 to avoid infinite recursion on cyclic dependency graph
        my (undef, $ext, $vars, @ns) = $s->(path => $file, lang => $lang, %$args, quick_deps => 2);
        $file = "$dirname$filename.$ext$lang";
        $data->{$file} = $vars;
        push @new_sources, @ns;
      }
      last;
    }
    $data->{$file}{headers}{title} //= ucfirst $filename;
  }
  my @d;
  while (my ($k, $v) = each %$data) {
    push @d, [$k, $v];
  }
  no warnings 'uninitialized'; # peculiar: should only happen with quick_deps>2
  # transform second argument to fetch_deps() from a hashref to an arrayref
  $_[1] = [sort {$b->[1]{mtime} <=> $a->[1]{mtime}} @d];

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

sub sitemap {
  my %args = @_;
  my $template = "content$args{path}";
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path});
  $args{deps} //= {};
  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  my $content = "";
  my ($filename, $dirname, $extension) = parse_filename $args{path};
  s/^[^.]+\.// for my $lang = $extension;
  if ($args{path} =~ m!/(index|sitemap)\b[^/]*$!) {
    $args{headers}{title} //= $title{$1}{$lang}
     . ucfirst basename($dirname);
  }

  for (grep shift @$_, sort {$a->[0] cmp $b->[0]} map {s!/index\.html\b[\w.-]*$!/! for my $path = $_->[0]; [$path, @$_]} @{$args{deps}}) {
    my $title = $$_[1]{headers}{title};
    my ($filename, $dirname) = parse_filename $$_[0];
    if ($$_[0] =~ m!/(index|sitemap|$)[^/]*$! and $title eq ucfirst($1 || "index")) {
      $title = $title{+($1 || "index")}{$lang}
          . ucfirst basename($dirname);
    }
    $content .= "- [$title]($$_[0])\n";
  }

  if ($args{nest}) {
    1 while $content =~ s{^(\s*-\s)                  # \1, prefix
              (                                      # \2, link
                  \[ [^\]]+ \]
                  \(
                  (  [^\)]* / ) index\.html\b[\w.-]* # \3, (dir with trailing slash)
                  \)
              )
              (                                      # \4, subpaths
                  (?:\n\1\[ [^\]]+ \]\( \3 (?!index\.html\b[\w.-]*)[^\#?] .*)+
              )
       }{
         my ($prefix, $link, $subpaths) = ($1, $2, $4);
         $subpaths =~ s/\n/\n    /g;
         "$prefix$link$subpaths"
       }xme;
  }
  $args{content} = $args{preprocess} ? Template($content)->render(\%args) : $content;

  # the extra (3rd) return value is for sitemap support
  return Template($template)->render(\%args), html => \%args, @new_sources;
}

# internal utility sub for the wrapper views that follow (not overrideable)

sub next_view {
  my $args = pop;
  $args->{view} = [@{$args->{view}}] if ref $args->{view}; # copy it since we're changing it
  return ref $args->{view} && @{$args->{view}} ? shift @{$args->{view}} : delete $args->{view};
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
  my @path = split m!/!, shift;
  pop @path;
  my @rv;
  my $relpath = "";
  for (@path) {
      $relpath .= "$_/";
      $_ ||= "Home";
      push @rv, qq(<a href="$relpath">\u$_</a>);
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

# wrapper view for pulling snippets out of code repos; see thrift site sources for sample usage
# 'snippet_footer' and 'snippet_header' args are supported.

sub snippet {
  my %args = @_;
  my $file = "content$args{path}";
  read_text_file $file, \%args unless exists $args{headers} and exists $args{content};
  my $key = "snippetA";
  $args{content} =~ s{\[snippet:([^\]]+)\]} # format is [snippet:arg1=val1:arg2=val2:...]
                     {
                         my $argspec = $1;
                         my %a = (%args, map {split /=/, $_, 2} split /:/, $argspec);
                         require SunStarSys::Value::Snippet; # see source for list of valid args
                         $args{$key} = SunStarSys::Value::Snippet->new(%a);
                         my $linenums = $a{numbers} ? "linenums" : "";
                         my $filter = exists $a{lang} ?  "markdown" : "safe";
                         my $rv = "<pre class='prettyprint $linenums prettyprinted'>{{ $key.fetch|$filter }}</pre>";
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
  $args{content} =~ s/                 # trim markdown links
                         \[
                         ( [^\]]+ )
                         \]
                         \(
                         ( (?!:http)[^\)#?]*? ) (?:\.\w+|\/) ([#?][^\)#?]+)?
                         \)
                   /[$1]($2$3)/gx;

  $args{content} =~ s/                 # trim html links
                         href=(['"])
                         ( (?!:http)[^'"?#]*? ) (?:\.\w+|\/) ([#?][^'"#?]+)?
                         \1
                     /href=$1$2$3$1/gx;

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
