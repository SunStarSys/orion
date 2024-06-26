#!/usr/local/bin/perl
#
# build site
#
# args:
# --target-base=path  path to destination dir
# --source-base=path  trunk or a branch
# --runners=N         number of runners to use (default 8)
# --offline           don't process "dynamic" content from SunStarSys::Value::*

use File::Basename;
use Cwd 'abs_path';
use POSIX qw/_exit/;
use IO::Select;
use List::Util qw/shuffle/;
use Socket;
use File::stat;
use Time::HiRes qw/gettimeofday tv_interval/;

BEGIN {
  my $script_path = dirname($0);
  $script_path = abs_path($script_path);
  $script_path =~ /(.*)/;
  $script_path = $1;
  unshift @INC, "$script_path/lib";
}

use utf8;
use strict;
use warnings;
use Getopt::Long;
use File::Path;
use SunStarSys::Util qw/copy_if_newer parse_filename unload_package/;
use SunStarSys::View;
use Data::Dumper ();
use SunStarSys::ASF;
use IO::Compress::Gzip qw/gzip/;
use Fcntl;
use base 'sealed';
#use sealed 'deparse';
sub syswrite_all;

my ($revision, $target_base, $source_base, $dirq, $runners, $offline, @errors);

GetOptions ( "target-base=s", \$target_base,
             "source-base=s", \$source_base,
             "dirqueue=s",    \$dirq,
             "runners=i",     \$runners,
             "offline",       \$offline,
             "revision=i",    \$revision,
);

die <<USAGE unless defined $target_base and -d $source_base;
Usage: $0 --source-base /path/to/trunk/or/a/branch --target-base /path/to/target [ --runners N ] [--offline]
USAGE

$_ = abs_path($_) and s!/+$!! for $source_base, $target_base;
$runners ||= 8; # 8 is arbitrary but educated guess

chdir $source_base or die "Can't chdir to $source_base: $!\n";
$ENV{TARGET_BASE} = $target_base;

my ($repos, $website) = $source_base =~ m!/([^/]+)/([^/]+)/(?:trunk|branches)\b!;
$ENV{REPOS} = $repos;
$ENV{WEBSITE} = $website;

open my $build_log, ">>:raw", "$target_base/.build-log/$revision.log" or die "Can't open .build-log/$revision.log: $!";

# fire and forget (blocking semantics are bad when users can disconnect the fifo we write to
for (\*STDOUT, \*STDERR, $build_log) {
  my $n = fileno $_;
  open $_, ">>&$n:raw" unless $_ == $build_log;
  my $flags = 0;
  $flags = fcntl $_, F_GETFL, $flags;
  $flags |= O_NONBLOCK;
  fcntl $_, F_SETFL, $flags;# or die "Can't set O_NONBLOCK on fd $n: $!";
  $|=1;
}

$SIG{__WARN__} = sub { local $_ = $_[0]; utf8::encode $_; syswrite $build_log, gmtime . ":$_"; warn $_};
$SIG{__DIE__}  = sub { local $_ = $_[0]; utf8::encode $_; syswrite $build_log, gmtime . ":$_"; die $_};

unshift @INC, "$source_base/lib";
require path;
require view;

{
    no warnings 'once';
    $SunStarSys::Value::Offline = 1 if $offline;
}

my $pattern_string = 'no strict "refs"; *path::patterns{ARRAY}';
my $patterns = eval $pattern_string;
my %seen;

sub main :Sealed {
  my $saw_error = 0;
  $runners = $path::runners if defined $path::runners and $path::runners < $runners;
  syswrite_all "Building site (runners = $runners)...\n";
  my @runners = map fork_runner(), 1..$runners;
  my @fd2rid;
  $fd2rid[fileno $runners[$_]->{socket}] = $_ for 0..$#runners;
  my @new_sources;
  my @dirqueue = $dirq // ("cgi-bin", "templates", "content");
  my IO::Select $sockets = "IO::Select";
  $sockets = $sockets->new;
  $sockets->add(map $_->{socket}, @runners);

 LOOP: while (@dirqueue) {
    my $would_block = 1;

    for my $p (shuffle $sockets->can_write(0)) {
      $would_block = 0;
      my $dir = shift @dirqueue or last;

      if (syswrite_all($p, "$dir\n") <= 0) {
	warn "syswrite_all failed: $! ", fileno $p;
	unshift @dirqueue, $dir;
	$sockets->remove($p);
	$runners[$fd2rid[fileno $p]]->{wait} = 1;
	close $p;
	$saw_error++;
	next;
      }
      $runners[$fd2rid[fileno $p]]->{wait} = 0;
    }
    last if $would_block;
  }

  for my $p ($sockets->can_read(3)) {
    local $_ = '';
    my $bytes;

    while (($bytes = sysread $p, $_, 4096, length) > 0) {
      last if substr($_, -1, 1) eq "\n";
    }
    if ($bytes <= 0) {
      warn "sysread failed: $! ", fileno $p;
      $sockets->remove($p);
      $runners[$fd2rid[fileno $p]]->{wait} = 1;
      close $p;
      $saw_error++;
      next;
    }
    push @dirqueue, grep length && $_ ne "working...", map /^new: (.+)$/ ? (push @new_sources, grep !$seen{$_}++, $1 and ()) : $_, split /\n/;
    $runners[$fd2rid[fileno $p]]->{wait} = /(?:^$)\Z/m;
  }

  goto LOOP if @dirqueue or grep !$_->{wait}, @runners;

  if (@new_sources) {
    syswrite_all "New content dectected: $_\n" for @new_sources;
    syswrite_all "Rebuilding site...\n";
    syswrite_all $_, "[flush]\n" for $sockets->can_write(0);
    @new_sources = ();
    @dirqueue = $dirq // ("cgi-bin", "templates", "content");
    goto LOOP;
  }

  shutdown $_, 1 for map $_->{socket}, @runners;
  syswrite_all "Waiting for kids...\n";
  $? && ++$saw_error while wait > 0; # if our assumptions are wrong, we'll know here
  syswrite_all "All done.\n";
  exit -1 if $saw_error;
  exit 0; # avoid global cleanup segfault
}

sub process_dir {
    my ($root, $wtr, $final) = @_;
    opendir my $dir, $root or warn "Can't open $root [skipping]: $!" and return;
    my $made_target_dir;

    no warnings 'uninitialized';
    for (map $_->[0], sort {$b->[1] <=> $a->[1]} map [$_, -d],# dirs first, schwartzian xform
         map "$root/$_", grep $_ ne "." && $_ ne ".." && $_ ne ".svn", readdir $dir) {

        if (-d and not $final) {
            if (m!\.page$!) {
                process_dir($_, $wtr, "final");
                next;
            }
            if (syswrite_all($wtr, "$_\n") <= 0) {
                warn "syswrite_all failed: $!";
            }
            next;
        }
        if (-f _) {
            mkpath "$target_base/$root" unless $made_target_dir++;
            syswrite_all($wtr, "new: $_\n") for eval { process_file($_) };
            push @errors, [$_, $@] if $@;
        }
        else {
            warn "skipping unrecognized entry: $_\n";
        }
    }
}

my %method_cache;

sub process_file :Sealed {
    my $file = shift;
    my ($filename, $dirname, $extension) = parse_filename $file;
    s/^([^.]+)//, $extension = $1 for my $lang = $extension;

    my $target_file = $dirname . $filename;
    s/^content// for my $target_path = $target_file;

    my $path = $file;
    $path =~ s!^content!! or goto COPY;

    for my $p (@$patterns) {
        my ($re, $method, $args) = @$p;
        next unless $path =~ $re;
        if ($args->{headers}) {
          my Data::Dumper $d = "Data::Dumper";
          $d = $d->new([$args->{headers}], ['$args->{headers}']);
          $d->Deepcopy(1);
          $d->Purity(1);
          eval $d->Dump;
        }
        my $s = $method_cache{$method} //= view->can($method) or die "Can't locate method: $method\n";
        my $start_call = [gettimeofday];
        my ($content, $ext, undef, @new_sources) = $s->(website => $ENV{WEBSITE}, repos => $ENV{REPOS}, path => $path, lang => $lang, %$args);
        my $elapsed = tv_interval($start_call);
        if ($$args{compress}) {
          $lang .= ".gz";
          if (defined $content) {
            utf8::encode($content) if utf8::is_utf8 $content;
            gzip \($content, my $compressed);
            $content = $compressed;
          }
        }
        if (defined $content) {
          my $dest = "$target_base/$target_file.$ext$lang";
          my $encoding = $$args{encoding} // ($$args{compress} ? "raw" : "encoding(UTF-8)");
          my $mtime;
          $mtime = $_->mtime for map stat $_, "content/$path";
          open my $fh, ">:$encoding", $dest
            or die "Can't open $dest: $!\n";
          print $fh $content;
          close $fh;
          utime $mtime, $mtime, $dest if $mtime;
        }
        syswrite_all "Built to $target_base/$target_file.$ext$lang in ${elapsed}s.\n";
        return @new_sources;
    }

  COPY:
    my ($dest, $copied) = copy_if_newer $file, "$target_base/$file";
    syswrite_all "Copied to $dest.\n" if $copied;

    return;
}

sub fork_runner :Sealed {
    socketpair my $child, my $parent, AF_UNIX, SOCK_STREAM, PF_UNSPEC
        or die "socketpair: $!";
    binmode $_ for $child, $parent;
    defined(my $pid = fork) or die "Can't fork: $!\n";
    if ($pid) {
        # in parent
        close $parent;
        return { pid => $pid, socket => $child, wait => 1 };
    }
    # in child
    close $child;
    my IO::Select $r = "IO::Select";
    $r = $r->new;
    $r->add($parent);

    while (1) {
        my ($p) = $r->can_read();
        # minor race condition: this issue seems inherent to any attempts
        # to communicate process state via sockets, and since we aren't
        # building software, but websites, the bang-for-the-buck tradeoff is
        # well worth the risks.

        # notify parent we are beginning work
        if (syswrite_all($parent, "working...\n") <= 0) {
            warn "syswrite_all failed: $!";
        }

        local $_ = '';
        my $bytes;
        while (($bytes = sysread $p, $_, 4096, length) > 0) {
            last if substr($_, -1, 1) eq "\n";
          }
        for (split /\n/) {
          if ($_ eq "[flush]") {
            SunStarSys::View::flush_memoize_cache;
            unload_package("path") or die "Can't unload package path\n";
            require "path.pm";
            $patterns = eval $pattern_string;
            die "ZOMG\n" unless @$patterns;
          }
          else {
            process_dir($_, $parent);
          }
        }
        last if $bytes <= 0;

        # notify parent we are waiting for more input
        if (syswrite_all($parent, "\n") <= 0) {
            warn "syswrite_all failed: $!";
        }
    }
    warn "File $_->[0] had processing errors: $_->[1]" for @errors;
    _exit -1 if @errors;
    _exit 0; # avoid segfault on global cleanup
}

sub syswrite_all {
    my $data = pop;
    my $fh = shift // \*STDOUT;
    my $bytes;
    my $total = 0;
    if ($fh == \*STDOUT) {
      my ($x) = map {my $x = $_; utf8::encode $x if utf8::is_utf8 $x; $x} $data;
      syswrite $build_log, $x;
    }
    while (($bytes = syswrite($fh, substr($data, $total))) > 0) {
      $total += $bytes;
      return $total if $total == length $data;
    }
    return $bytes;
}

main();

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
