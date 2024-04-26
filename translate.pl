#!/usr/bin/env -S perl -Ilib
use utf8;
use strict;
use warnings FATAL => 'all';
use SunStarSys::Util qw/read_text_file parse_filename Dump Load/;
use Cpanel::JSON::XS;
use APR::Request qw/decode/;

sub translate;

mkdir "$ENV{HOME}/.oci", 0700;
mkdir "$ENV{HOME}/.ssh", 0700;

my ($src, $targ) = @ARGV;

$SIG{__WARN__} = sub { warn "SRC=$src\n"; warn @_ };
my ($s_base, $s_dir, $s_ext) = parse_filename $src;
my ($t_base, $t_dir, $t_ext) = parse_filename $targ;
s/^[^.]*\.// for my $s_lang = $s_ext;
s/^[^.]*\.// for my $t_lang = $t_ext;
$targ = $src unless length "$t_dir$t_base";

read_text_file $src, \ my %s_args;
my %t_args;
my @keys = qw/title categories keywords published archived status acl/;

@{$t_args{headers}}{@keys} = translate $s_lang, $t_lang, @{$s_args{headers}}{@keys} if keys %{$s_args{headers}};

delete $t_args{headers}{acl} unless defined $s_args{headers}{acl};

my (@headings, @code_blocks, @katex_strings, @dtls, @mdlinks, @snippets, @key_prefixes, @entities, @newlines);

$s_args{content} =~ s/\n{2}\s+/\n\n/g;

$s_args{content} =~ s{^(#+ )}{
  push @headings, $1;
  "<!--  -->"
}ge;
$s_args{content} =~ s{(^\`{3}[\w-]+\n.*?\n\`{3}$|<(script|style).*?</\2>)}{
  push @code_blocks, $1;
  "<!-- # -->"
}gmse;
$s_args{content} =~ s{(\${2}.*?\${2}|<span class="editormd-tex">.*?</span>)}{
  push @katex_strings, $1;
  "<!-- ## -->"
}msge;
$s_args{content} =~ s{(\{[\%\#\{].*?[\%\#\}]\})}{
  push @dtls, $1;
  "<!-- ### -->"
}msge;
$s_args{content} =~ s{(]\([^)]+?)(\s+[^\)]*)?\)}{
  no warnings 'uninitialized';
  push @mdlinks, "$1", ")";
  "<!-- #### -->$2<!-- #### -->";
}ge;

$s_args{content} =~ s{(\[(?:snippet:[^\]]+|TOC)\])}{
  push @snippets, $1;
  "<!-- ##### -->"
}ge;

if ($s_ext =~ /^(ya?ml|bib)\b/) {
  $s_args{content} =~ s{^(\s*(?:- )?[\w-]+\s*[:=] )}{
    push @key_prefixes, $1;
    "<!-- ###### -->"
  }gmse;
}
$s_args{content} =~ s{(\&\S+;|\`|!?\[|])}{
  push @entities, $1;
  "<!-- ####### -->"
}ge;
$s_args{content} =~ s{(?<!\n)\n(?!\n)}{
  push @newlines, "\n";
  "<!-- ######## -->"
}ge;

$t_args{content} = join "\n\n", translate $s_lang, $t_lang, split /\n\n/, $s_args{content};
$t_args{content} =~ s{<!-- ######## -->}{shift @newlines}ge;
$t_args{content} =~ s{<!-- ####### -->}{shift @entities}ge;
$t_args{content} =~ s{<!-- ###### -->}{shift @key_prefixes}ge;
$t_args{content} =~ s{<!-- ##### -->}{shift @snippets}ge;
$t_args{content} =~ s{<!-- #### -->}{shift @mdlinks}ge;
$t_args{content} =~ s{<!-- ### -->}{shift @dtls}ge;
$t_args{content} =~ s{<!-- ## -->}{shift @katex_strings}ge;
$t_args{content} =~ s{<!-- # -->}{shift @code_blocks}ge;
$t_args{content} =~ s{<!--  -->}{shift @headings}ge;

## oci rendering fixups
# NEEDS WORK: $t_args{content} =~ s/"([^"]+)"[(]/[$1](/g;
$t_args{content} =~ s/\)\n\n/).\n\n/g;

if (exists $s_args{headers}{dependencies}) {
  s/\.$s_lang/.$t_lang/g, utf8::encode $_ for $t_args{headers}{dependencies} = $s_args{headers}{dependencies};
}

open my $fh, ">:utf8", $targ or die "open '$targ' failed: $!";
if (keys %{$t_args{headers}}) {

  utf8::encode $_ for grep defined, map ref($_) eq "HASH" ? values %$_ : ref($_) eq "ARRAY" ? @$_ : $_, values %{$t_args{headers}};
  my $headers = Dump $t_args{headers};
  utf8::decode $headers;
  print $fh "$headers---\n\n";
}
print $fh $t_args{content};
exit 0;

sub translate {
  my ($s_lang, $t_lang, @args) = @_;
  my @obj;
  for my $idx (1..@args) {
    push @obj, {
      key => "$idx",
      languageCode => $s_lang,
      text => $args[$idx-1],
    };
  }

  my @rv;
  my $idx;
 LOOP:
  my @cobj = ();
  push @cobj, shift @obj while @obj and @cobj < 100;
  return @rv unless @cobj;
  warn ++$idx;
  local $_ = Cpanel::JSON::XS->new->utf8(1)->encode(\@cobj);
  open my $fh, ">:encoding(UTF-8)", ".translate.json";
  print $fh $_;
  close $fh;
  eval {
    $rv[$_->{key}-1+($idx-1)*100] = do {
      for ($_->{"translated-text"}) {
        s/\\u([0-9a-f]{4})/decode('%u' . $1)/ge;
        utf8::upgrade $_;
        s/&lt;/</g;
        s/&gt;/>/g;
      }
      $_->{"translated-text"}
    } for map @{$_->{data}->{documents}},
    Load($_ = scalar qx(docker run -t -v \$(pwd):/src -v $ENV{HOME}/.ssh:/home/ubuntu/.ssh -v $ENV{HOME}/.oci:/home/ubuntu/.oci --entrypoint= schaefj/linter oci ai language batch-language-translation --target-language-code $t_lang --documents file://.translate.json));
  };
  die "oci ai language ... failed: $?: $_: $@" if $? or $@;
  goto LOOP;
}
