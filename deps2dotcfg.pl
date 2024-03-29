#!/usr/bin/env -S perl -Ilib
# requires a www/.deps file, a and graphviz install for the `dot` shell command
# yields per-lang deps.gv.* config files, and per-language deps.svg.gz.* files.
use utf8;
use strict;
use warnings;
use YAML::XS;
$| = 1;
return 1 unless -f "www/.deps";
open my $fh, "<:encoding(UTF-8)", "www/.deps", or die "Can't open www/.deps: $!";
read $fh, my $content, -s $fh or die "WTF?";
my $yaml_deps = Load $content;

my $nn = 0;

my @language = qw/English Spanish German French/;
my @lang = qw/.en .es .de .fr/;

my $red_edge_re = shift;

for my $idx (0..3) {
  my ($root) = grep s!trunk/content!!, <trunk/content/sitemap.*$lang[$idx]> or die "Can't find root document: $!";
  warn "root is $root for $lang[$idx]\n";
  my @dep_nodes = ($root);
  my %dot;
  while (@dep_nodes and (my $node = shift @dep_nodes)) {
    next unless exists $yaml_deps->{$node};
    $dot{$node} = {
      deps => $yaml_deps->{$node},
      id => $nn++,
      name => "\"$node\""
    };
    push @dep_nodes, @{$dot{$node}{deps}};
    delete $yaml_deps->{$node};
  }

  open $fh, ">:encoding(UTF-8)", "deps.gv$lang[$idx]", or die "Can't open deps.gv$lang[$idx]: $!";
  print $fh "strict digraph \"$language[$idx] Dependencies\" {\n";

  for (sort {$a->{id} <=> $b->{id}} values %dot) {
    print $fh "$_->{name} [name=$_->{name}];\n";
    for my $value (map $dot{$_} || $_, @{$_->{deps}}) {
      $value = $dot{$value} = { deps => $$yaml_deps{$value}, id => $nn++, name=>"\"$value\""} unless ref $value;
      my $color = "";
      $color=" [color=red]" if defined $red_edge_re and $value->{name} =~ $red_edge_re;
      print $fh "$_->{name} -> $value->{name}$color;\n";
    }
  }
  print $fh "}\n";
  close $fh;
  print "Vertices: ";
  system "grep -Evce '->|\\{|\\}' deps.gv$lang[$idx]";
  print "Edges: ";
  system "grep -Fce '->' deps.gv$lang[$idx]";
  print "Generating deps.svg$lang[$idx].gz ...";
  system "dot -Tsvgz deps.gv$lang[$idx] > deps.svg$lang[$idx].gz";
  print " done.\n";
}
