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
use SunStarSys::Util qw/read_text_file sort_tables parse_filename sanitize_relative_path Dump Load/;
use Data::Dumper ();
use File::Basename;
use File::Path;
use IO::Compress::Gzip 'gzip';
use LWP::UserAgent;
use URI::Escape;
use SunStarSys::SVNUtil;
use POSIX qw/:locale_h/;
use locale;

our %LANG = (
  ".de" => "de_DE.UTF-8",
  ".en" => "en_US.UTF-8",
  ".es" => "es_ES.UTF-8",
  ".fr" => "fr_FR.UTF-8",
);

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

sub single_narrative {
  my %args = @_;
  my $path = $args{path};
  my $file = "content$args{path}";
  my $template = $args{template};
  $args{deps} //= {};

  read_text_file $file, \%args unless exists $args{content} and exists $args{headers};
  setlocale $_, $LANG{$args{lang}} for LC_ALL;
  $template = $args{headers}{template} if exists $args{headers}{template};

  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path});

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

  my $headers = Dump $args{headers};
  my $categories = delete $args{headers}{categories};
  my $archive_headers = Dump $args{headers};
  my $keywords = $args{headers}{keywords};
  my $status = $args{headers}{status} // "draft";

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
    for my $f (grep {not -f} "$archive_dir/index.html$lang", dirname($archive_dir)."/index.html$lang") {
      open my $fh, ">:encoding(UTF-8)", $f
        or die "Can't open archive to $f: $!\n";
      my $type = $f eq "$archive_dir/index.html$lang" ? "year" : "month";
      print $fh <<EOT;
{% include "$type.html" %}
EOT
      push @new_sources, $f;
    }
  }

  $categories = [sort split /[;,]\s*/, $categories] if defined($categories) and not ref $categories;
  $keywords = [sort split /[;,]\s*/, $keywords] if defined($keywords) and not ref $keywords;

  if (exists $args{category_root}
      and exists $args{headers}
      and defined $categories) {

    my $category_root = "content$args{category_root}";

    for my $cat (@{$categories}) {
      unless (-f (my $f = "$category_root/$cat/$filename.$ext")) {
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

      for my $f (grep {not -f} "$category_root/$cat/index.html$lang") {
        open my $fh, ">:encoding(UTF-8)", $f
          or die "Can't categorize $f: $!\n";
        print $fh <<EOT;
{% include "category.html" %}
EOT
        push @new_sources, $f;
      }
    }
  }

  $_ .= "/$filename.html$lang" for grep defined, $args{archive_path};
  $args{headers}{categories} = $categories if defined $categories;
  $args{headers}{keywords} = $keywords if defined $keywords;
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
    my $ua = LWP::UserAgent->new;
    my $cached = 0;
    -d $attachments_dir or mkpath $attachments_dir;
    if (-f "$attachments_dir/$prefix.asy$lang" and open my $fh, "<:encoding(UTF-8)", "$attachments_dir/$prefix.asy$lang") {
      read $fh, my $content, -s $fh;
      if ($content eq $body) {
        ++$cached;
      }
    }
    unless ($cached) {
      open my $fh, ">:encoding(UTF-8)", "$attachments_dir/$prefix.asy$lang" or die $!;
      print $fh $body;
      push @sources, "$attachments_dir/$prefix.asy";
      my $res = LWP::UserAgent->new->post('http://192.168.254.1:8080/', Content => $body);
      if ($res->is_success) {
        -d $attachments_dir or mkpath $attachments_dir;
        my $file = "$attachments_dir/$prefix.html$lang";
        if (open my $fh, ">:encoding(UTF-8)", $file) {
          print $fh $res->decoded_content;
          push @sources, $file;
        }
      }
      else {
        die "asy html rendering of '$prefix' failed (" . $res->status_line . "): " . $res->decoded_content;
      }
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
  my $dependencies = eval '*path::dependencies{HASH}';
  my $patterns = eval '*path::patterns{ARRAY}';

  for (@{$$dependencies{$path}}) {
    my $file = $_;
    next if exists $data->{$file};
    my ($filename, $dirname, $extension) = parse_filename;
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
        $file .= ".gz" if $$args{compress};
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
        $file .= ".gz" if $$args{compress};
        $data->{$file} = $vars;
        push @new_sources, @ns;
      }
      last;
    }
    $data->{$file}{headers}{title} //= ucfirst $filename;
  }
  my @d;
  while (my ($k, $v) = each %$data) {
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
  $args{breadcrumbs} = view->can("breadcrumbs")->($args{path});
  $args{deps} //= {};
  my @new_sources = view->can("fetch_deps")->($args{path} => $args{deps}, $args{quick_deps});

  my $content = "";
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
    $lede = " &mdash; $lede..." if $lede;
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
                  \)
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

=pod

  my $lang = $args{lang};
  my $page_path = "content$args{path}";
  my ($base) = parse_filename $page_path;
  my $attachments_dir = dirname($page_path) . "/$base.page";
  -d $attachments_dir or mkpath $attachments_dir;

  open my $fh, ">:encoding(UTF-8)", "$attachments_dir/index.json$lang" or die "Can't open 'index.json$lang' :$!";

=cut

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

# recursively evaluates ssi tags in content

sub ssi {
  my %args = @_;
  my $file = "content/$args{path}";
  read_text_file $file, \%args unless defined $args{headers} and defined $args{content};

  1 while $args{content} =~ s/(\{%\s*ssi\s+\`[^\`]+\`\s*%\})/Template($1)->render({})/ge;
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
  my @path = split m!/!, shift;
  pop @path;
  my @rv;
  my $abspath = "";
  for (@path) {
      $abspath .= "$_/";
      $_ ||= "Home";
      push @rv, qq(<a href="$abspath">\u$_</a>);
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
