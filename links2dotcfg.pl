#!/usr/bin/env -S perl -Ilib
# requires a www/.deps file, a and graphviz install for the `dot` shell command
# yields per-lang deps.gv.* config files, and per-language deps.svg.gz.* files.
#
# You can use this script for any static website, by plopping the documentroot into www/content, and doing something like this for a rootfile at index.html:
#
# % ./links2dotcfg.pl '^$' index ""
#
# the "index" arg overrides "sitemap" as the starting point for the link walk.
# the "" arg will override the multiviews languages inherent to sunstarsys.com
#

use utf8;
use strict;
use warnings;
use YAML::XS;
use SunStarSys::Util qw/read_text_file/;
use File::Basename;
$| = 1;
my $nn = 0;

my $red_edge_re = shift;

my $root_file_base = shift // "sitemap";

my @language = qw/English Spanish German French/;
my @lang = @ARGV ? @ARGV : qw/.en .es .de .fr/;
for my $idx (0..$#lang) {
  my ($root) = grep s!www/content!!, <www/content/$root_file_base.*$lang[$idx]> or die "Can't find root document at /$root_file_base: $!";
  warn "root is $root for $language[$idx]: '$lang[$idx]'\n";

  my @link_nodes = ($root);
  my %links;
  while (@link_nodes and (my $node = shift @link_nodes)) {
    next if exists $links{$node};
    $links{$node} = {
      id => $nn++,
      name => "\"$node\""
    };
    next if $node !~ /\.html/;
    read_text_file "www/content$node", \ my %data;
    $data{content} //= "";
    while ($data{content} =~ /
                         <[^>]+(href|src|action)=(['"])
                         ( (?!https?:|mailto:)[^'"?#]*? ) ([#?][^'"#?]+)?
                         \2/gx) {
      my $url = $3;
      if (substr($url, 0, 1) ne "/") {
        $url = dirname($node) . "/$url";
      }
      $url =~ s!/\./!/!g;
      1 while $url =~ s#/[^/]+/\.\./#/#;
      push @{$links{$node}{links}}, $url;
    }

    push @link_nodes, @{$links{$node}{links} ||[]};
  }

  open my $fh, ">:encoding(UTF-8)", "links.gv$lang[$idx]", or die "Can't open links.gv$lang[$idx]: $!";
  print $fh "strict digraph \"$language[$idx] Links\" {\noverlap=scale;\n";

  for (sort {$a->{id} <=> $b->{id}} values %links) {
    print $fh "$_->{name} [name=$_->{name}];\n";
    for my $value (map $links{$_} || $_, @{$_->{links}}) {
      my $color = "";
      $color = " [color=red]" if defined $red_edge_re and $value->{name} =~ $red_edge_re;
      print $fh "$_->{name} -> $value->{name}$color;\n";
    }
  }
  print $fh "}\n";
  close $fh;
  print "Vertices: ";
  system "grep -Evce '->|\\{|\\}' links.gv$lang[$idx]";
  print "Edges: ";
  system "grep -Fce '->' links.gv$lang[$idx]";
  print "Generating links.svg.gz$lang[$idx] ...";
  system "twopi -Tsvgz links.gv$lang[$idx] > links.svg.gz$lang[$idx]";
  print " done\n";
}
