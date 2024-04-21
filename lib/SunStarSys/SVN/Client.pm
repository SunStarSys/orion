package SunStarSys::SVN::Client;
# ithread-safe SVN::Client (delegation model)
use warnings;
use strict;
use APR::Pool;
use SVN::Core;
use SVN::Client;
use SVN::Delta;
use SunStarSys::Util qw/normalize_svn_path get_lock/;
use File::Basename qw/dirname basename/;
use Fcntl qw/SEEK_SET/;
use base "sealed";

no warnings 'redefine';
#__PACKAGE__ declarations for sealed method lookups
sub _create_auth;
sub new;
sub add;
sub merge;
sub update;
sub copy;
sub move;
sub delete;
sub status;
sub info;
sub diff;
sub log;

# accessors
sub r       {shift->{r}}
sub client  {shift->{client}}
sub context {shift->{client}->{ctx}}
sub pool    {shift->{pool}}

sub _create_auth :Sealed {
  my $pool = pop;
  my Apache2::RequestRec $r = pop or return [];
  $r = $r->main unless $r->is_initial_req;
  my $authcb = sub {
    my $cred = shift;
    $cred->username($r->pnotes("svnuser"));
    $cred->password($r->pnotes("svnpassword"));
    $cred->may_save(0);
  };

  return [
    SVN::Client::get_ssl_server_trust_file_provider($pool),
    SVN::Client::get_simple_prompt_provider($authcb, 1, $pool),
  ];
}

sub SVN::Client::log_msg {
  my $self = shift;

  if (@_) {
    my $rv = shift;
    $self->{'log_msg_callback'} = [\$rv, $self->{'ctx'}->log_msg_baton3($rv)];
  }
  return $$self{'log_msg_callback'}[-1];
}

sub SVN::Client::config {
  my $self = shift;
  if (@_) {
    $self->{config} = $self->{ctx}->config(shift, $self->{pool});
  }
  return $self->{config};
}

sub SVN::Client::notify {
  my $self = shift;
  if (@_) {
    my $rv = shift;
    $self->{notify_callback} = [\$rv, $self->{ctx}->notify_baton($rv)];
  }
  return $$self{notify_callback}[-1];
}

sub new :Sealed {
  my SVN::Client $client = "SVN::Client";
  my SunStarSys::SVN::Client $class = shift;
  my Apache2::RequestRec $r = shift;
  local $_ = $r ? $r->pool : $SVN::Core::gpool;
  my $pool = $r ? bless $_, "_p_apr_pool_t" : $_;
  unshift @_, auth => $class->_create_auth($r, $pool), pool => $pool, config => {};
  $client = $client->new(@_) or die "Can't create SVN::Client: $!";
  return bless {
    r      => $r,
    client => $client,
    pool   => $pool,
  }, $class;
}

sub add :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($filename, $recursive) = @_;
  my SVN::Client $svn = $self->client;
  normalize_svn_path $filename;
  $svn->add4($filename, $recursive ? $SVN::depth::infinity : $SVN::depth::empty, 0, 0, 1);
}

sub merge :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($filename, $target_path, $target_revision, $dry_run) = @_;
  ($filename, $target_path) = map dirname($_), $filename, $target_path if $filename !~ m#/$#;

  normalize_svn_path $filename, $target_path;

  my Apache2::RequestRec $r = $self->r;
  my SVN::Client $svn = $self->client;
  my (@add, @delete, @restore, @update, @conflict);
  my %dispatch = (
    $SVN::Wc::Notify::Action::add           => \@add,
    $SVN::Wc::Notify::Action::update_add    => \@add,
    $SVN::Wc::Notify::Action::update_delete => \@delete,
    $SVN::Wc::Notify::Action::restore       => \@restore,
    $SVN::Wc::Notify::Action::update_update => \@update,
    $SVN::Wc::Notify::State::conflicted     => \@conflict,
);

  $svn->notify(sub {
    my ($path, $action, undef, undef, $state) = @_;
    $path =~ s!^\Q$filename\E/?!!;
    push @{$dispatch{$state}}, $path and return 1 if exists $dispatch{$state};
    push @{$dispatch{$action}}, $path if exists $dispatch{$action};
  });
  local $_;

  my $rv = "--- ";

  if ($target_revision !~ /^-/) {
    $svn->merge_peg3(
      $target_path,
      [1, $target_revision],
      $target_revision,
      $filename,
      $SVN::Depth::infinity, #1, recursive
      0, # ignore_ancestry
      0, # force
      0, # record-only
      $dry_run,
      undef
    );
    $rv .= "Merging r$target_revision into '.':\n";
  }
  else {
    $svn->merge3(
      $filename, #src1
      -$target_revision, #rev1
      $filename, #src2
      -$target_revision - 1, #rev2
      $target_path, # path
      $SVN::Depth::infinity,#1, # recursive
      1, # ignore_ancestry
      0, # force
      0, #record-only
      $dry_run,
      undef
    );
    $rv .= "Reverse-merging r" . (-$target_revision) . " into '.':\n";
  }
  $rv .= "C   $_\n" for @conflict;
  $rv .= "M   $_\n" for @update;
  $rv .= "A   $_\n" for @add;
  $rv .= "R   $_\n" for @restore;
  $rv .= "D   $_\n" for @delete;

  return $rv;

}

sub update :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($filename, $depth) = @_;
  normalize_svn_path $filename;
  my $dir = dirname $filename;
  my Apache2::RequestRec $r = $self->r;
  my SVN::Client $svn = $self->client;
  my (@add, @delete, @restore, @update, @conflict);
  my %dispatch = (
    $SVN::Wc::Notify::Action::add           => \@add,
    $SVN::Wc::Notify::Action::update_add    => \@add,
    $SVN::Wc::Notify::Action::update_delete => \@delete,
    $SVN::Wc::Notify::Action::restore       => \@restore,
    $SVN::Wc::Notify::Action::update_update => \@update,
    $SVN::Wc::Notify::State::conflicted     => \@conflict,
  );

  $svn->notify(sub {
    my ($path, $action, undef, undef, $state) = @_;
    $path =~ s!^\Q$filename\E/?!!;
    push @{$dispatch{$state}}, $path and return 1 if exists $dispatch{$state};
    push @{$dispatch{$action}}, $path if exists $dispatch{$action};
  });

  $depth = $SVN::Depth::infinity; # hard-coded
  my $revision = $svn->update3($filename, "HEAD", $depth, 1,  1, 0);
  my $rv = "--- Updated '.' to HEAD:\n";
  $rv .= "C   $_\n" for @conflict;
  $rv .= "U   $_\n" for @update;
  $rv .= "A   $_\n" for @add;
  $rv .= "R   $_\n" for @restore;
  $rv .= "D   $_\n" for @delete;

  return $rv;
}

sub copy :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($source, $target) = @_;
  normalize_svn_path $_ for $source, $target;
  my SVN::Client $client = $self->client;
  $client->copy($source, 'WORKING', $target);
}

sub move :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($source, $target, $force) = (@_, 1);
  normalize_svn_path $_ for $source, $target;
  my SVN::Client $client = $self->client;
  $client->move($source, undef, $target, $force);
}

sub delete :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($filename, $force) = (@_, 1);
  normalize_svn_path $filename;
  my SVN::Client $client = $self->client;
  $client->delete($filename, $force);
}

my @status;
eval '$status[$SVN::Wc::Status::' . "$_]=qq/\u$_/"
    for qw/modified conflicted added deleted unversioned
           normal ignored missing replaced obstructed/;

sub status :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my Apache2::RequestRec $r = $self->r;
  my SVN::Client $client = $self->client;
  my ($filename, $depth) = (@_, wantarray ? $SVN::Depth::immediates :$SVN::Depth::empty);
  my $prefix = $filename;
  $prefix =~ s![^/]+$!!;
  normalize_svn_path $filename;
  my @rv;
  my $callback = sub :Sealed {
    my $path = shift;
    my _p_svn_wc_status2_t $status = shift or return 0;
    $path =~ s!^\Q$prefix\E!!
      or $path = "./";
    push @rv, [$path => $status[$_]] for $status->text_status;
    return 0;
  };
  my $pool = $self->pool;

  $client->status4($filename, $SVN::Delta::INVALID_REVISION, $callback, $depth, (0) x 4, undef);
  return map @$_, @rv if wantarray;
  return $rv[0]->[1];
}

sub info :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my Apache2::RequestRec $r = $self->r;
  my SVN::Client $client = $self->client;
  my ($filename, $callback, $remote_revision) = @_;
  normalize_svn_path $filename;
  $client->info($filename, undef, $remote_revision, $callback, 0);
}

sub mkdir :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my SVN::Client $client = $self->client;
  my ($url, $make_parents) = (@_, 1);
  $url =~/(.*)/;
  $client->mkdir3($1, $make_parents, undef);
}

sub diff :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my SVN::Client $client = $self->client;
  my ($filename, $recursive, $revision) = @_;
  my $base_revision = $revision ? $revision - 1 : "BASE";
  my Apache2::RequestRec $r = $self->r;
  normalize_svn_path $filename;
  open my $dfh, "+>", undef or die "DFH open failed: $!";
  open my $efh, "+>", undef or die "EFH open failed: $!";

  my $relative_path = $filename;
  if ($revision) {
    $self->info($filename, sub {$filename = $_[1]->URL});
    s/-internal//, s/:4433// for $filename;
  }
  local $@;
  eval { $client->diff5([], $filename, $base_revision, $filename, $revision // 'WORKING', undef, $recursive ? $SVN::Depth::infinity : $SVN::Depth::immediates, 0, 1, 1, 0, 1, "en_US.UTF-8", $dfh, $efh, []) };
  warn $@ if $@;
  seek $_, 0, SEEK_SET for $dfh, $efh;
  my $rv = join "", <$efh>, <$dfh>;
  utf8::decode($rv);
  return $rv;
}

sub log :Sealed {
  my SunStarSys::SVN::Client $self = shift;
  my ($filename, $prevision, $frevision, $limit) = @_;
  my SVN::Client $svn = $self->client;
  $limit //= 1 if defined $prevision and $prevision ne "HEAD";
  $prevision //= 'HEAD';
  $self->info($filename, sub {$filename = $_[1]->URL});
  s/-internal//, s/:4433// for $filename;
  s!/cms-sites/.*$!! for my $prefix = $filename;
  my @rv;
  my @props = qw/svn:log svn:author svn:date/;
  local $@;
  eval {$svn->log5(
    $filename, undef, [$prevision, $frevision // 1], $limit // 100, 1, 0, 1, \@props, sub :Sealed {
      my _p_svn_log_entry_t $log_entry = shift;
      my %cp2;
      @cp2{keys %{$log_entry->changed_paths2}} = map +{action => $_->action, text_modified => $_->text_modified, props_modified => $_->props_modified}, values %{$log_entry->changed_paths2};
      push @rv, [$log_entry->revision, \%cp2, grep utf8::decode($_), @{$log_entry->revprops}{@props}];
    })};
  return \@rv;
}

our $AUTOLOAD;

sub AUTOLOAD {
  no strict 'refs';
  my ($method_name) = (split /::/, $AUTOLOAD)[-1];
  return if $method_name eq "DESTROY";

  if (defined(my $client_method = $_[0]->client->can($method_name))) {
    *$AUTOLOAD = sub :Sealed {
      my SunStarSys::SVN::Client $self = shift;
      my Apache2::RequestRec $r = $self->{r};
      my SVN::Client $client = $self->{client};
      my $file_idx = $method_name =~ /prop_?get/ ? 1 : $method_name =~ /prop_?set/ ? 2 : 0;
      my $filename = $_[$file_idx];
      if (ref $filename) {
        normalize_svn_path @$filename if ref $filename eq "ARRAY";
        $filename = $r->filename;
      }
      else {
        if ($file_idx > 0 and $method_name =~ /rev/) {
          $self->info($filename, sub {$filename = $_[1]->URL});
          s/-internal//, s/:4433// for $filename;
        }
        else {
          normalize_svn_path $filename;
        }
        splice @_, $file_idx, 1, $filename;
      }
      my ($repos, $user, $lock) = $filename =~ m{^/x1/cms/wc(?:build)?/([^/]+)/([^-/]+)};
      $lock = get_lock("/x1/cms/locks/$repos-wc-$user") if defined $repos and defined $user;
      $client_method->($client, @_); # SVN::Client::$client_method will push ctx and pool args.
    };
    goto &{*{$AUTOLOAD}{CODE}};
  }
  die "$AUTOLOAD(): method not found!";
}

eval {__PACKAGE__->new->log_msg(sub {})};
eval {__PACKAGE__->new->commit};
eval {__PACKAGE__->new->cleanup(__FILE__)};
eval {__PACKAGE__->new->propget(__FILE__)};
1;
