#!/usr/bin/env perl
#
use utf8;
use strict;
use warnings;
use YAML::XS;

return 1 unless -f "www/.deps";
open my $fh, "<:encoding(UTF-8)", "www/.deps", or die "Can't open www/.deps: $!";
read $fh, my $content, -s $fh or die "WTF?";
my $yaml_deps = Load $content;

my $nn = 0;

my ($root) = grep s!trunk/content!!, <trunk/content/sitemap.*.en> or die "Can't find root document: $!";

my @dep_nodes = ($root);
my %dot;
while (@dep_nodes and (my $node = shift @dep_nodes)) {
  warn $node;
  next unless exists $yaml_deps->{$node};
  $dot{$node} = {
    deps => $yaml_deps->{$node},
    id => $nn++,
    name => "\"$node\""
  };
  warn for @{$dot{$node}{deps}};
  push @dep_nodes, @{$dot{$node}{deps}};
  delete $yaml_deps->{$node};
}

open $fh, ">:encoding(UTF-8)", "deps.gv", or die "Can't open deps.gv: $!";
print $fh "strict digraph Dependencies {\n";

for (sort {$a->{id} <=> $b->{id}} values %dot) {
  print $fh "$_->{name} [name=$_->{name}];\n";
  for my $value (map $dot{$_} || $_, @{$_->{deps}}) {
    $value = $dot{$value} = { deps => $$yaml_deps{$value}, id => $nn++, name=>"\"$value\""} unless ref $value;
    print $fh "$_->{name} -> $value->{name};\n";
  }
}
print $fh "}\n";
close $fh;
