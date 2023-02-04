package SunStarSys::SVNUtil;

# assumes svn 1.7+, but will mostly work with prior versions

use SVN::Client;
use SVN::Wc;
use SVN::Delta;
use SVN::Core;
use APR::Pool;
use strict;
use warnings;
use base 'Exporter';
use SunStarSys::Util qw/normalize_svn_path/;
our @EXPORT = qw/svn_up svn_status svn_add svn_rm svn_ps is_version_controlled *USERNAME *PASSWORD/;
our $VERSION = "1.0";
our ($USERNAME, $PASSWORD) = @ENV{qw/SVN_USERNAME SVN_PASSWORD/};

sub auth {
    my $authcb = sub {
        my $cred = shift;
        $cred->username($USERNAME);
        $cred->password($PASSWORD);
        $cred->may_save(0);
    };
    return [
        SVN::Client::get_ssl_server_trust_file_provider(),
        SVN::Client::get_simple_prompt_provider($authcb, 1),
        ];
}

sub new { return SVN::Client->new( auth => auth ) }

sub svn_up {
    my $ctx = shift->new;
    my $svn_base = shift;
    my $revision = shift;
    my (@add, @delete, @restore, @update);
    my %dispatch = (
        $SVN::Wc::Notify::Action::add             => \@add,
        $SVN::Wc::Notify::Action::update_add      => \@add,
	$SVN::Wc::Notify::Action::commit_added    => \@add,
        $SVN::Wc::Notify::Action::update_delete   => \@delete,
        $SVN::Wc::Notify::Action::commit_replaced => \@update,
        $SVN::Wc::Notify::Action::restore         => \@restore,
        $SVN::Wc::Notify::Action::update_update   => \@update,
    );

    $ctx->notify(sub {
        my ($path, $action) = @_;
        $path =~ s!^\Q$svn_base/!!;
        push @{$dispatch{$action}}, $path if exists $dispatch{$action};
    });

    $ctx->cleanup($svn_base);
    $ctx->revert($svn_base, 1);
    $revision = eval { $ctx->update($svn_base, $revision, 1) } // $revision;
    if ($@) {
        my ($wc_root_path) = map /^Working Copy Root Path: (.*)$/, `svn info '$svn_base'`
            or die "Can't find Working Copy Root Path!\n";
        $ctx->cleanup($wc_root_path);
        $revision = $ctx->update($svn_base, $revision, 1);
    }

    print "Updated $svn_base to revision $revision.\n";
    return add => \@add, delete => \@delete, restore => \@restore, update => \@update,
           revision => $revision;
}

my %st_dispatch = (
    'M'  => "modified",
    'A'  => "added",
    'D'  => "deleted",
    '?'  => "unversioned",
    '!'  => "missing",
    'C'  => "conflicted",
    'I'  => "ignored",
    'R'  => "replaced",
    'X'  => "external",
    '~'  => "obstructed",
);

my @status;
eval '$status[$SVN::Wc::Status::' . "$_]=qq/\u$_/"
    for qw/modified conflicted added deleted unversioned
           normal ignored missing replaced obstructed/;

sub _status {
    my $client = shift->new;
    my ($filename, $depth) = (@_, wantarray ? $SVN::Depth::infinity : $SVN::Depth::empty);
    normalize_svn_path $filename;
    my @rv;
    my $callback = sub {
        my $path = shift;
	my _p_svn_wc_status2_t $status = shift;
        $path =~ s!^\Q$filename\E!!;
	push @rv, [$path => $status[$_]] for $status->text_status;
	return 0;
    };

    $client->status4($filename, $SVN::Delta::INVALID_REVISION, $callback, $depth, (0) x 4, undef);
    return map @$_, @rv if wantarray;
    return $rv[0]->[1];
}

sub svn_status {
    my %status = _status(@_);
    my %rv;
    # ignores property mods, etc.; turns out we don't need them for our use-case
    while (my($k, $v) = each %status) {
        push @{$rv{+lc  $v}}, $k if defined $v;
    }
    return %rv;
}

sub svn_commit {
  my $ctx = shift->new;
  $ctx->log_msg(sub { ${$_[0]} = "Automated commit-back" });
  $ctx->commit(@_);
}

sub svn_revert {
  my $ctx = shift->new;
  $ctx->revert(@_);
}

sub svn_cleanup {
  my $ctx = shift->new;
  $ctx->cleanup(@_);
}

sub svn_add {
    my $ctx = shift->new;
    print "Adding $_.\n" and $ctx->add($_, 1) for @_;
}

sub svn_rm {
    my $ctx = shift->new;
    print "Removing $_.\n" and $ctx->delete($_, 1) for @_;
}

sub svn_ps {
    my $ctx = shift->new;
    my ($target, $propname, $propval) = @_;
    print "Setting '$propname' on $target.\n"
        and $ctx->propset($propname, $propval, $target, 0);
}

sub svn_diff {
  my $ctx = shift->new;
  my ($target, $revision, $recursive, $out, $err) = @_;
  $ctx->diff(undef, $target, $revision-1, $target, $revision, $recursive, 0, 1,
$out // \*STDOUT, $err // \*STDERR);
}

my %scr_cache;
sub svn_can_read {
  return unless exists $ENV{TARGET_BASE};
  my $ctx = shift->new;
  my $filename = shift;
  normalize_svn_path $filename;
  require Cwd;
  $filename = Cwd::cwd . "/$filename" unless index($filename, "/") == 0;
  return if $scr_cache{$filename} or not $filename =~ s#^/x1/cms/wcbuild/([^/]+)/##;
  my $url = "https://vcs.sunstarsys.com/repos/svn/$1/cms-sites/$filename";
  $ctx->info($url, "HEAD", "HEAD", sub {shift}, 0);
  ++$scr_cache{$filename};
}

my %vc_cache;
sub is_version_controlled {
  local $@;
  eval {__PACKAGE__->_status(@_)};
  return not $@;
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
