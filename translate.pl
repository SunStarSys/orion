#!/usr/bin/env -S perl -Ilib
use utf8;
use strict;
use warnings;
use SunStarSys::Util qw/read_text_file parse_filename Dump Load/;
use Cpanel::JSON::XS;
use APR::Request qw/decode/;

sub translate;

my ($src, $targ) = @ARGV;
my ($s_base, $s_dir, $s_ext) = parse_filename $src;
my ($t_base, $t_dir, $t_ext) = parse_filename $targ;
s/^[^.]*\.// for my $s_lang = $s_ext;
s/^[^.]*\.// for my $t_lang = $t_ext;


read_text_file $src, \ my %s_args;
my %t_args;
my @keys = qw/title categories keywords status acl/;

@{$t_args{headers}}{@keys} = translate $s_lang, $t_lang, @{$s_args{headers}}{@keys};

delete $t_args{headers}{acl} unless defined $t_args{headers}{acl};

my (@html, @code_blocks, @katex_strings, @dtls, @mdlinks, @snippets, @key_prefixes);

#$s_args{content} =~ s{(<[^>]+>|[&]\w+;)}{
#  push @html, $1;
#  "&nbsp;"
#}ge;

$s_args{content} =~ s{^(\`{3}[\w-]+\n.*?\n\`{3})$}{
  push @code_blocks, $1;
  "<!-- # -->"
}gmse;
$s_args{content} =~ s{(\${2}.*?\${2})}{
  push @katex_strings, $1;
  "<!-- ## -->"
}ge;
$s_args{content} =~ s{(\{[\%\#\{].*?[\%\#\}]\})}{
  push @dtls, $1;
  "<!-- ### -->"
}ge;
$s_args{content} =~ s{](\(.*?\))}{
  push @mdlinks, $1;
  "]<!-- #### -->"
}ge;
$s_args{content} =~ s{(\[snippet:[^\]]+\])}{
  push @snippets, $1;
  "<!-- ##### -->"
}ge;

if ($s_ext =~ /^ya?ml\b/) {
  $s_args{content} =~ s{^(\s*(?:- )?[\w-]+: )}{
    push @key_prefixes, $1;
    "<!-- ###### -->"
  }gmse;
}

$t_args{content} = join "\n\n", translate $s_lang, $t_lang, split /\n\n/, $s_args{content};
#$t_args{content} =~ s{\Q&nbsp;}{shift @html}ge;
$t_args{content} =~ s{<!-- ###### -->}{shift @key_prefixes}ge;
$t_args{content} =~ s{<!-- ##### -->}{shift @snippets}ge;
$t_args{content} =~ s{<!-- #### -->}{shift @mdlinks}ge;
$t_args{content} =~ s{<!-- ### -->}{shift @dtls}ge;
$t_args{content} =~ s{<!-- ## -->}{shift @katex_strings}ge;
$t_args{content} =~ s{<!-- # -->}{shift @code_blocks}ge;

if (exists $s_args{headers}{dependencies}) {
  s/\.$s_lang/.$t_lang/g, utf8::encode $_ for $t_args{headers}{dependencies} = $s_args{headers}{dependencies};
}

open my $fh, ">:utf8", $targ or die "open '$targ' failed: $!";
my $headers = Dump $t_args{headers};
utf8::decode $headers;
print $fh "$headers---\n\n";
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
  push @rv, map {
    s/\\u([0-9a-f]{4})/decode('%u' . $1)/ge;
    utf8::upgrade $_;
    s/&lt;/</g;
    s/&gt;/>/g;
    $_
  } map $_->{"translated-text"}, sort {$a->{key} <=> $b->{key}} map @{$_->{data}->{documents}},
  Load scalar qx(oci ai language batch-language-translation --target-language-code $t_lang --documents file://.translate.json);
  goto LOOP;
}
