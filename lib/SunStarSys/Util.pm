package SunStarSys::Util;
use base 'Exporter';
use YAML::XS;
use File::Basename;
use File::Copy;
use File::Find;
use IO::Compress::Gzip 'gzip';
use Cwd;
use File::stat;
use Fcntl ":flock";
use Time::HiRes qw/gettimeofday tv_interval/;
use APR::Pool;
use SVN::Repos;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use v5.38;
use utf8;
use constant MAX_LINK_COUNT => 1024;
use constant MAX_LINK_RAND  => 16;
our @HDR_FIELDS = qw/status title keywords categories acl type/;

our @EXPORT_OK = qw/sanitize_relative_path read_text_file copy_if_newer get_lock shuffle sort_tables fixup_code
                    unload_package purge_from_inc touch normalize_svn_path parse_filename get_lucy_indexer
                    walk_content_tree archived seed_file_deps seed_file_acl Load Dump %action_en/;
no warnings 'once';

our $VERSION = "3.2";

sub parse_filename;
sub read_text_file;
sub seed_file_deps;
sub seed_file_acl;

our $p;

UNITCHECK {
  $p = bless APR::Pool->new, "_p_apr_pool_t";
  eval{SVN::Core::utf_initialize($p)};
}

my %actions;
my @actions = qw/edit update revert copy move delete add commit diff mail merge production promote resolve rollback search static account comment watch unwatch like unlike markmap archived verified/;

for my $yml_file (map /^(.*)$/, </x1/cms/build/fields.yml.*>) {
  my (undef, undef, $ext) = parse_filename $yml_file;
  s/^[^.]*\.// for my $lang = $ext;
  read_text_file $yml_file, \ my %args;
  my $yml = Load map {utf8::encode($_); $_} $args{content};
  $actions{$lang} =[map {utf8::decode($_); $_} @$yml{@actions}];
}

our %action_en;

for (keys %actions) {
    for my $idx (0.. $#{$actions{en}}) {
	$action_en{$actions{$_}[$idx]} = $actions{en}[$idx];
    }
}

# utility for parsing txt files with headers in them
# and passing the args along to a hashref (in 2nd arg)

# memoization (a'la <ring.h>) to control RAM usage during large-scale builds
my $rtf_ring_hdr = { next => undef, prev => undef, cache => {}, count => 0 };
our $RTF_RING_SIZE_MAX = 1_000; #tunable

sub read_text_file {
  my ($file, $out, $content_lines) = @_;

  if ($ENV{MOD_PERL} and $file =~ m!^content/!) {
    s!/content/.*!!s for my $prefix = Apache2::RequestUtil->request->uri;
    $file = "$prefix/$file";
  }

  utf8::is_utf8 $file or utf8::decode $file unless ref $file;
  utf8::is_utf8 $$file and utf8::encode $$file if ref $file;

  $out->{mtime} = $_->mtime for map File::stat::populate(CORE::stat(_)), grep -f, $file;
  $out->{mtime} //= -1;
  warn "$file not a text file nor a reference" and return unless -T _ or ref $file;
  my $cache = $rtf_ring_hdr->{cache}{$file};

  if (defined $cache and $cache->{mtime} == $out->{mtime}) {

    @{$out->{headers}}{keys %{$cache->{headers}}} = values %{$cache->{headers}};

    if (defined $content_lines and $content_lines < $cache->{lines}) {
      no warnings 'uninitialized';
      $out->{content} = join "\n", (split "\n", $cache->{content})
        [0..($content_lines-1)], "" if $content_lines > 0;
      $out->{content} = "" if $content_lines == 0;
    }
    else {
      $out->{content} = $cache->{content};
    }

    if ($rtf_ring_hdr->{next} != $cache->{link}) {
      # MRU to front

      my $link = $cache->{link};
      $link->{prev}{next} = $link->{next};
      $link->{next}{prev} = $link->{prev} if $link->{next};
      $link->{next} = $rtf_ring_hdr->{next};
      $rtf_ring_hdr->{next} = $link;
      $link->{prev} = undef;
      $link->{next}{prev} = $link;
    }

    return $cache->{lines};
  }

  $file =~ /^(.*)$/, $file = $1, utf8::encode $file unless ref $file;
  my $encoding = ref $file ? "raw" : "utf8";
  open my $fh, "<:$encoding", $file or die "Can't open file $file: $!\n";

  my $headers = 1;
  local $_;
  my $content = "";
  my $BOM = "\xEF\xBB\xBF";
  my $hdr = {};

 LOOP:
  while (<$fh>) {
    utf8::decode $_ if ref $file;
    if ($headers) {
      if ($. == 1) {
        s/^$BOM//;
        if (/^---\s*$/) {
          my $yaml = "";
          while (<$fh>) {
            utf8::decode $_ if ref $file;
            last if /^---\s*$/;
            $yaml .= $_;
          }
          utf8::encode $yaml;
          $hdr = Load($yaml);
          utf8::decode $_ for grep defined, map ref($_) eq "HASH" ? values %$_ : ref($_) eq "ARRAY" ? @$_ : $_, values %$hdr;
          $headers = 0, next LOOP;
        }
      }
      $headers = 0, next if /^\r?\n/;
      my ($name, $val) = split /:\s+/, $_, 2;
      $headers = 0, redo LOOP
        unless $name =~ /^[\w-]+$/ and defined $val;
      $name = lc $name;
      chomp $val;
      while (<$fh>) {
        utf8::decode $_ if ref $file;
        $$hdr{$name} = $val, redo LOOP
          unless s/^\s+(?=\S)/ /;
        chomp;
        $val .= $_;
      }
      $$hdr{$name} = $val;
    }
    last LOOP if defined $content_lines and $content_lines-- == 0;
    no warnings 'uninitialized';
    $content .= $_;
  }
  if (exists $hdr->{atom}) {
    for ($hdr->{atom}) {
      if (/^(\S+)\s*(?:"([^"]+)")?\s*$/)  {
        $_ = { url => $1, title => $2 || "" };
      }
    }
  }

  @{$out->{headers}}{keys %$hdr} = values %$hdr;
  $out->{content} = $content;
  no warnings 'uninitialized';
  return $. unless eof $fh and $out->{mtime} > 0;

  $content .= $_;

  if (defined $cache) {
    # file modified on disk; clear cache and link

    my $rm_me = $cache->{link};
    for (qw/prev next/) {
      $rtf_ring_hdr->{$_} = $rm_me->{$_} if $rtf_ring_hdr->{$_} == $rm_me;
    }
    $rm_me->{prev}{next} = $rm_me->{next} if $rm_me->{prev};
    $rm_me->{next}{prev} = $rm_me->{prev} if $rm_me->{next};
    undef %$cache;
    undef %$rm_me;
    $rtf_ring_hdr->{count}--;
  }

  # add link to front

  my $link = { file => $file, next => $rtf_ring_hdr->{next}, prev => undef };
  $rtf_ring_hdr->{next} = $link;
  $rtf_ring_hdr->{prev} //= $link;
  $link->{next}{prev} = $link if $link->{next};
  $rtf_ring_hdr->{count}++;

  while ($rtf_ring_hdr->{count} > $RTF_RING_SIZE_MAX) {
    # drop LRU

    my $rm_me = $rtf_ring_hdr->{prev};
    $rtf_ring_hdr->{prev} = $rm_me->{prev};
    $rtf_ring_hdr->{next} = undef unless $rm_me->{prev};
    $rm_me->{prev}{next} = undef if $rm_me->{prev};
    delete $rtf_ring_hdr->{cache}{$rm_me->{file}};
    undef %$rm_me;
    $rtf_ring_hdr->{count}--;
  }

  $rtf_ring_hdr->{cache}{$file} = {
    content => $content,
    headers => $hdr,
    lines   => $.,
    link    => $link,
    mtime   => $out->{mtime},
  };

  return $.;
}

sub copy_if_newer {
    my ($src, $dest) = @_;
    die "Undefined arguments to copy($src, $dest)\n"
        unless defined $src and defined $dest;
    my $copied = 0;
    my $compress = 0;
    $dest .= ".gz" and $compress++ if !$ENV{NO_COPY_COMPRESS} and -T $src and $dest =~ m#/content/# and basename($src) ne ".htaccess";
    utf8::encode $_ for my ($s, $d) = ($src, $dest);
    copy $s, $d and $copied++ unless -f $dest and stat($src)->mtime < stat($dest)->mtime;
    if ($compress and $copied) {
      gzip $d, "$d.tmp";
      rename "$d.tmp", $d;
    }
    chmod 0755, $dest if -x $src;
    return $dest, $copied;
}

# NOTE: This will break your runtime if you call this on a package
# that imports/exports symbols or has any other external references
# to its available symbols.  The package also should be a leaf package,
# ie not have any subpackages within its namespace.

sub obliterate_package {
  my $pkg = shift;

  # expand to full symbol table name if needed

  unless ($pkg =~ /^main::.*::$/) {
    $pkg = "main$pkg"       if      $pkg =~ /^::/;
    $pkg = "main::$pkg"     unless  $pkg =~ /^main::/;
    $pkg .= '::'            unless  $pkg =~ /::$/;
  }

  no strict 'refs';

  my($stem, $leaf) = $pkg =~ m/^(.*::)(\w+::)$/ or die "Bad fqpn '$pkg'.\n";;
  my $stem_symtab = *{$stem}{HASH};
  return unless defined $stem_symtab and exists $stem_symtab->{$leaf};

  # free all the symbols and types in the package
  my $leaf_symtab = *{$stem_symtab->{$leaf}}{HASH};
  foreach my $name (keys %$leaf_symtab) {
    my $fullname = $pkg . $name;
    undef $$fullname;
    undef @$fullname;
    undef %$fullname;
    undef &$fullname unless $pkg eq "main::path::";
    undef *$fullname;
  }
  # delete the symbol table

  %$leaf_symtab = ();
  delete $stem_symtab->{$leaf};
}

sub unload_package {
  my $package = shift;
  obliterate_package $package;
  my $modpath = $package;
  s!::!/!g, $_ .= ".pm" for $modpath;
  return delete $INC{$modpath};
}

sub purge_from_inc {
  for my $d (@_) {
    for my $id (grep $INC[$_] eq $d, reverse 0..$#INC) {
      splice @INC, $id, 1;
    }
  }
}

sub get_lock {
    my $lockfile = shift;
    $lockfile =~ m!^(/x1/cms/locks/[^/]+)$! or die "Invalid lock file: $lockfile";
    open my $lockfh, "+>", $1
        or die "Can't open lockfile $lockfile: $!\n";
    flock $lockfh, LOCK_EX
        or die "Can't get exclusive lock on $lockfile: $!\n";
    return $lockfh;
}

sub touch {
    @_ or push @_, $_ if defined;
    for (@_) {
      my $file = $_;
      utf8::encode $file;
      utime undef, undef, $file and next;
        open my $fh, ">>", $file
            or die "Can't open $file: $!\n";
        close $fh;
        utime undef, undef, $file
            or die "Can't touch $file: $!\n";
    }
}

#ttc
sub sanitize_relative_path {
  for (@_ ? @_ : $_) {
    s#^[\\/]+##g;
    s/^\w+://g; #Windows GRR
    s#([\\/])+#$1#g;
    s#/\./#/#g;
    1 while s#[\\/][^\\/]+[\\/]\.\.[\\/]#/#;
    s#^(?:\.\.?[\\/])+##;
  }
}
#ttc

sub normalize_svn_path {
  for (@_? @_ : $_) {
    $_ //= "";
    tr!/!/!s;
    s!/$!!;
    s!^(https?):/!$1://!;
    s!/\./!/!g;
    1 while s!/[^/]+/\.\.(/|$)!$1!;
    utf8::downgrade $_;
  }
  return 1;
}

sub shuffle {
    my $deck = shift;  # $deck is a reference to an array
    return unless @$deck; # must not be empty!
    my $i = @$deck;
    while (--$i) {
        my $j = int rand ($i+1);
        @$deck[$i,$j] = @$deck[$j,$i];
    }
}

# arbitrary number of tables supported, but only one col per table may be sorted

sub sort_tables {
  use locale;
  my @orig = split /\n/, shift, -1;
  my @out;
  local $_;
  while (defined($_ = shift @orig))  {
    push @out, $_;
    /^(\|[ :vn^-]+)+\|$/ or next;
    my($data, $col, $direction, $cur, $numeric);
    $cur = 0;
    while (/\|([ :vn^-]+)/g) {
      $data = $1;
      if ($data =~ tr/v/v/) {
        $col = $cur;
        $direction = -1;
        last;
      }
      elsif ($data =~ tr/^/^/) {
        $col = $cur;
        $direction = 1;
        last;
      }
      $cur++;
    }
    $out[-1] =~ tr/vn^//d;
    $numeric = 1 if $data =~ tr/n/n/;
    unless (defined $col) {
      push @out, shift @orig while @orig and $orig[0] =~ /^\|/;
      next;
    }
    my @rows;
    push @rows, [split /\s*\|\s*/, shift(@orig), -1]
      while @orig and $orig[0] =~ /^\|/;
    shift @$_, pop @$_ for @rows; # dump empty entries at ends
    @rows = $numeric
      ? sort { $a->[$col] <=> $b->[$col] } @rows
      : sort { $a->[$col] cmp $b->[$col] } @rows;
    @rows = reverse @rows if $direction == -1;
    push @out, map "| " . join(" | ", @$_) . " |", @rows;
  }

  return join "\n", @out;
}

sub parse_filename {
  my ($f) = (@_, $_);
  my ($filename, $dirname, $ext) = fileparse $f, qr!\.[^/]+$!;
  $ext = "." unless length $ext;
  return $filename, $dirname, substr $ext, 1;
}

sub fixup_code {
  my $prefix = shift;
  my $type   = shift;

  for (@_) {
    s/^\Q$prefix//mg if defined $prefix;
    $_ = "$type\x00$_"
      if defined $type;
  }
}

sub get_lucy_indexer {
  local $@;
  eval <<'EOT';
use Lucy::Plan::Schema;
use Lucy::Plan::FullTextType;
use Lucy::Plan::StringType;
use Lucy::Analysis::EasyAnalyzer;
use Lucy::Index::Indexer;

package LightMergeManager;
use base qw/Lucy::Index::IndexManager/;
sub recycle {
    my $self = shift;
    my $seg_readers = $self->SUPER::recycle(@_);
    @$seg_readers = grep { $_->doc_max < 25 } @$seg_readers;
    return $seg_readers;
}
package NoMergeManager;
use base qw/Lucy::Index::IndexManager/;
sub recycle {[]}
EOT
  return if $@ or not @path::patterns;
  my $truncate = shift;
  my %analyzer = map +($_ => eval{Lucy::Analysis::EasyAnalyzer->new(language => $_)} // undef), map m#\.([^./]+)$#, </x1/cms/build/fields.yml.*>;
  my %indexer;
  while (my ($k, $v) = each %analyzer) {
    delete($analyzer{$k}), next unless $v;
    $indexer{$k} = Lucy::Index::Indexer->new(index => ".lucy.$k", manager => LightMergeManager->new) and next unless $truncate;

    my $schema = Lucy::Plan::Schema->new;
    $schema->spec_field(name => "path", type => Lucy::Plan::StringType->new(sortable => 1));

    my $type = Lucy::Plan::FullTextType->new(analyzer => $v);
    $schema->spec_field(name => $_, type => $type) for content => @HDR_FIELDS;
    $indexer{$k} = Lucy::Index::Indexer->new(index => ".lucy.$k", schema => $schema, create => 1, truncate => 1);
  }
  return %indexer;
}

my $dep_string = 'no strict "refs"; *path::dependencies{HASH}';
my $dependencies;

my $acl_string = 'no strict "refs"; *path::acl{ARRAY}';
my $acl;

my $link_string = 'no strict "refs"; *SunStarSys::View::links{HASH}';
my $links;
my %links_orig;

sub walk_content_tree :prototype(&) {
  my $wanted = shift;
  $dependencies = eval $dep_string;
  $acl = eval $acl_string;
  $links = eval $link_string;

  if (-f "$ENV{TARGET}/.deps") {
      # use the cached .deps file if the incremental build system deems it appropriate
      open my $deps, "<:raw", "$ENV{TARGET}/.deps" or die "Can't open .deps for reading: $!";
      eval '*path::dependencies = Load join "", <$deps>';
      $dependencies = eval $dep_string;
  }
  if (-f "$ENV{TARGET}/.acl") {
      open my $fh, "<:raw", "$ENV{TARGET}/.acl" or die "Can't open .acl for reading: $!";
      eval '*path::acl = Load join "", <$fh>';
      $acl = eval $acl_string;
      #utf8::decode $_ for map {$_->{path}, values %{$_->{rules}}} @$acl;
  }
  if (-f "$ENV{TARGET}/.links") {
      open my $fh, "<:raw", "$ENV{TARGET}/.links" or die "Can't open .links for reading: $!";
      %SunStarSys::View::links = %{Load join "", <$fh>};
      $links = eval $link_string;
      utf8::decode $_ for values %$links;
      %links_orig = %$links;
  }
  return if eval '$path::use_cache';

  my $cwd = cwd;
  local $_; # filepath that $wanted sub should inspect, rooted in content/ dir
  my $start_time = [gettimeofday];
  my %indexer = get_lucy_indexer(1);
  my $nproc = `nproc` + 0;

  find({ wanted => sub {
           s!^\Q$cwd/content!!;
	   my (undef, undef, $ext) = parse_filename;
	   s/^[^.]+\.// for my $lang = $ext;

	   my $s = sub {
             seed_file_deps, seed_file_acl;
	     read_text_file "content$_", \ my %args;
	     my $h = delete $args{headers};
	     %$h = map +($_ => $$h{$_} // ""), @HDR_FIELDS;
	     require Dotiac::DTL;
	     state $t = Dotiac::DTL::Template("{{content|striptags|safe}}");
	     state $r = $t->can("render");
	     1 while $args{content} =~ s/!?\[([^\[\]]+)]\([^\)]+\)/$1/g; # poor man markdown link/img demunger
	     %args = (%$h, content => $r->($t,\%args), path => $_);
	     if (exists $indexer{$lang}) {
	       state $add_doc = $indexer{$lang}->can("add_doc");
	       $add_doc->($indexer{$lang},\%args);
	     }
	   };

	   $s->() if -f and $ext =~ /^(?:md|ya?ml|csv)\b/;
           $wanted->();
         }, no_chdir => 1 }, "$cwd/content");

  $_->commit for values %indexer;
  my $elapsed = tv_interval $start_time;
  warn "Walked content tree in ${elapsed}s.\n";
  return 1;
}

END {
  if ($dependencies) {
    open my $deps, ">:raw", "$ENV{TARGET}/.deps" or die "Can't open '.deps' for writing: $!";
    utf8::is_utf8($_) and utf8::encode $_ for map @$_, values %$dependencies;
    utf8::is_utf8($_) and utf8::encode $_ for keys %$dependencies;
    print $deps Dump $dependencies;
  }
  if ($acl) {
    open my $fh, ">:raw", "$ENV{TARGET}/.acl" or die "Can't open '.acl' for writing: $!";
    utf8::is_utf8($_) and utf8::encode $_ for map {$_->{path}, values %{$_->{rules}}} @$acl;
    print $fh Dump $acl;
  }
  if (keys %$links) {
    open my $fh, ">:raw", "$ENV{TARGET}/.links" or die "Can't open '.links' for writing: $!";
    for my $k (keys %$links) {
      no warnings 'uninitialized';
      utf8::is_utf8 $_ and utf8::encode $_ for $$links{$k};
      my $v = $$links{$k};
      my ($title, $img, $count) = split /%%/, $v;
      my (undef, undef, $orig_count) = split /%%/, $links_orig{$k};
      $count += int rand(MAX_LINK_RAND),
	$$links{$k} = join '%%', $title, $img, $count
	if $count == $orig_count;
      delete $$links{$k} if $count > MAX_LINK_COUNT;
    }
    print $fh Dump $links;
  }
}

sub archived {
  my ($path) = (@_, $_);
  my $file = "content$path";
  return unless -T $file;
  read_text_file $file, \ my %data;
  no warnings 'uninitialized';
  return $action_en{lc($data{headers}{status})} eq "archived";
}

# invoke this inside a walk_content_tree {} block:
# parses deps from file $_'s content and headers

sub seed_file_deps {
  my ($path) = (@_, $_);
  utf8::decode $path unless utf8::is_utf8 $path;
  my $dir = dirname($path);
  read_text_file "content$path", \ my %d;
  no strict 'refs';
  return if archived $path;
  my ($base, undef, $ext) = parse_filename $path;
  my $old_deps = delete $$dependencies{$path};
  my %seen;
  @{$$dependencies{$path}} = grep !$seen{$_}++, @{$$dependencies{$path} // []},
    grep {
      utf8::decode $_ unless utf8::is_utf8 $_;
      sanitize_relative_path;
      s/^content// and $_ ne $path and not archived;
    }
    map glob("content$_"), map {index($_, "/") == 0  ? $_ : "'$dir'/$_"}
    ref $d{headers}{dependencies} ? @{$d{headers}{dependencies}} : split /[;,]?\s+/, $d{headers}{dependencies} // "";

  no warnings 'uninitialized';
  while ($d{content} =~ /\{%\s*(include|ssi)\s+[\`"]([^\`"]+)[\`"]\s*-?%\}/g) {
    my $ssi = $1 eq "ssi";
    my $src = $2;
    if ($ssi or index($src, "./") == 0 or index($src, "../") == 0) {
      $src = "$dir/$src", $src = s(/[.]/)(/)g unless $ssi;
      sanitize_relative_path $src; $src = "/$src";
      y/+/ / for $src;
      push @{$$dependencies{$path}}, $src unless archived $src or $seen{$src}++;
    }
  }
  my $attachments_dir = "content$dir/$base.page";
  if (-d $attachments_dir) {
    s/^[^\.]*// for my $lang = $ext;
    push @{$$dependencies{$path}}, grep {sanitize_relative_path; s/^content// && !$seen{$_}++} glob("'$attachments_dir'/*$lang");
  }

  local $@;
  my ($idx, $author);
  {
    local $SIG{__WARN__} = sub {};
    state $_foo = eval 'BEGIN{require SunStarSys::SVN::Client}';
  }
  state $pool = bless APR::Pool->new, "_p_apr_pool_t";
  state $svn = bless { client => eval {SVN::Client->new(pool => $pool)} || undef }, "SunStarSys::SVN::Client";

  for my $dep_path (@{$$dependencies{$path}}) {
    splice @{$$dependencies{$path}}, $idx--, 1
      if !(grep $dep_path eq $_, @$old_deps) and $svn->client and
      eval { $svn->info("content$path", sub {$author = $_[1]->last_changed_author}) unless $author;
	     SVN::_Repos::svn_repos_authz("accessof", "--repository" => $ENV{REPOS},
        "--path" => "/cms-sites/$ENV{WEBSITE}/(?:[^/]+/)+?content$dep_path", "--username" => $author // '*',
        "--groups-file" => "$ENV{TARGET}/group-svn.conf",
        "$ENV{TARGET}/authz-svn.conf", $pool)};

    ++$idx;
  }

  delete $$dependencies{$path} unless @{$$dependencies{$path}};
}

sub seed_file_acl {
  my ($path) = (@_, $_);
  utf8::decode $path unless utf8::is_utf8 $path;
  read_text_file "content$path", \ my %d;
  my @restrictions;
  my @p = $path;
  my %seen;
  # no laundering
  while (@p) {
    my $p = shift @p;
    for (grep !$seen{$_}++, @{$$dependencies{$p}}) {
      read_text_file "content$_", \ my %d;
      push(@restrictions, map /\S+\s*=\s*[^rw\s]/g, $d{headers}{acl}) if $d{headers}{acl};
      push @p, $_;
    }
  }
  no strict 'refs';
  my ($prior) = grep $acl->[$_]{path} eq "content$path", 0..$#$acl;
  if (defined $prior) {
    return unless $acl->[$prior]{unlocked};
    splice @$acl, $prior, 1 and return unless $d{headers}{acl};
    $acl->[$prior]{rules} = {map {split /\s*=\s*/, $_, 2} split(/[,;]?\s+/, $d{headers}{acl}), @restrictions};
    $acl->[$prior]{rules}{'@svnadmin'} = 'rw';
  }
  elsif (exists $d{headers}{acl}) {
    push @$acl, {
      path     => "content$path",
      unlocked => 1,
      rules    => {map {split /\s*=\s*/, $_, 2} split(/[;,]?\s+/, $d{headers}{acl}), @restrictions}
    };
    $$acl[-1]{rules}{'@svnadmin'} = 'rw';
  }

  return 1;
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
