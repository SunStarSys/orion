package SunStarSys::Value::Snippet;
use LWP::UserAgent;
use URI;
use SunStarSys::Util qw/fixup_code/;
use APR::Request 'encode';
use strict;
use warnings;
use threads;
use threads::shared;

sub new {
    my $class = shift;
    my %args = @_;
    # args: type=>github or svn, path=>..., token=>..., lang=>..., prefix=>...,
    #       branch=>branch, repo=>repo, revision=>revision, lines=>lines, numbers=>1

    $args{branch} //= "master";
    $args{type} //= $args{repo} ? "github" : "svn";
    my $uri = $args{type} eq "svn" ? "https://vcs.sunstarsys.com/repos/svn/public/cms-sites/$args{path}"
        : $args{type} eq "github"
        ? "https://github.com/$args{repo}/raw/$args{branch}/$args{path}"
        : undef;

    if (exists $args{revision} and $args{type} eq "svn") {
        $uri .= "?p=$args{revision}";
    }

    my $obj = bless {
        uri     => $uri,
        path    => $args{path},
        token  => $args{token},
        lang    => $args{lang},
        prefix  => $args{prefix},
        type    => $args{type},
        lines   => $args{lines} && [$args{lines} =~ m/(\d+)/g],
        numbers => $args{numbers},
    }, $class;

    return $obj;
}

my %cache :shared;

sub fetch {
    return if $SunStarSys::Value::Offline;
    my ($self) = @_;

    my $content = $cache{$self->{uri}} //= do {
        die "Unsupported repo type: $self->{type}" unless defined $self->{uri};
        my $response = LWP::UserAgent->new(ssl_opts=>{verify_hostname=>0})->get(URI->new($self->{uri}));
        die "Can't fetch $self->{uri}: " . $response->status_line unless $response->is_success;
        $response->decoded_content;
    };

    if (defined $self->{token}) {
      my ($start, $end) = split /,/, $self->token;
      $end = $start unless $end;
      $content =~ /^(.*?)^\Q$start\E.*?\n(.*?)^\Q$end/ms
	or die "Can't find $self->{token} block at $self->{uri}";
      $content = $2;
      my $preamble = $1;
      while (1) {
	$_[0]->{lines}->[1] = $_[0]->{lines}->[0] = ($preamble =~ y/\n//) + 2;
	$_[0]->{lines}->[1] += ($content =~ tr/\n/\n/) - 1;
	if ($_[0]->{lang} eq "perl" and $self->{token} =~ /^=/) {
	  $_[0]->{lang} = "pod";
	  require Pod::PlainText;
	  local (*STDIN, *STDOUT);
	  my $p = Pod::PlainText->new(sentence => 0); 
	  my ($start) = split /,/, $self->{token};
	  $content = "$start\n$content";
	  open  *STDIN, "<", \$content;
	  open *STDOUT, "+>", undef;
	  $p->parse_from_filehandle;
	  seek *STDOUT, 0, 0;
	  read *STDOUT, $content, -s *STDOUT;
	  redo;
	}
	last;
      }
    }
    elsif ($self->{lines}) {
        $content = join "\n", grep {defined || ! warn "Missing lines from $self->{uri}"}
            (undef, split /\n/, $content)
                [($self->{lines}->[0] // 1) .. ($self->{lines}->[1] // $content =~ y/\n//)];
    }

    #$content =~ s/^(\s+):::/$1#!/ if $self->{numbers};
    return $content;
}

sub pretty_uri {
    my $self = shift;
    my $uri = $self->{uri};
    my $token = encode($self->{token}//"");
    $uri =~ s!repos/svn!viewvc! if $self->{type} eq "svn";
    if ($self->{type} eq "github") {
      $uri =~ s!/raw/!/blob/!;
      if ($self->{lines}) {
        $uri .= "#L" . join "-L", @{$self->{lines}};
      }
      elsif ($token) {
	my ($start, $end) = split /,/, $token;
	$end = $start unless $end;
	$uri .= "#:~:text=$start,,$end";
      }
    }
    return $uri;
}

sub DESTROY {
    undef %{shift()};
}

sub AUTOLOAD {
    my ($attr) = our $AUTOLOAD =~ /::(\w+)$/;
    die "$attr attribute not found" unless exists $_[0]->{$attr};
    no strict 'refs';
    *{$AUTOLOAD} = sub { shift->{$attr} };
    goto &$AUTOLOAD;
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
