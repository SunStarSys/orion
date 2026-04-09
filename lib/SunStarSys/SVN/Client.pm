package SunStarSys::SVN::Client;
use v5.38;
# ithread-safe SVN::Client (delegation model)
use APR::Pool;
use Apache2::RequestRec;
use Apache2::ServerUtil;
use SVN::Core;
use SVN::Client;
use SVN::Delta;
use SVN::Repos;
use SVN::Fs;
use SunStarSys::Util qw/normalize_svn_path get_lock/;
use File::Basename qw/dirname basename/;
use Fcntl qw/SEEK_SET/;
use base "sealed"; # ANON
use sealed;
use threads::shared;
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

# classname aliases

use constant AR => "Apache2::RequestRec";
use constant SVN => "SVN::Client";

use constant string  => "";
use constant boolean => "";
use constant integer => "";
use constant coderef => "";
use constant hashref => "";


# ctor helper

sub _create_auth (string $class, AR $r, _p_apr_pool_t $pool) {
  my $authcb = sub :Sealed {
    my _p_svn_auth_cred_simple_t $cred = shift;
    $cred->username($r->pnotes("svnuser"), $pool);
    $cred->password($r->pnotes("svnpassword"), $pool);
    $cred->may_save(0);
  };

  return [
    SVN::Client::get_ssl_server_trust_file_provider($pool),
    SVN::Client::get_simple_prompt_provider($authcb, 1, $pool),
  ];
}

# monkey patching
no warnings 'redefine';

sub _log_msg (SVN $self, coderef $rv = undef) {
  if (defined $rv) {
    $self->{'log_msg_callback'} = [\$rv, $self->{'ctx'}->log_msg_baton3($rv)];
  }
  return $$self{'log_msg_callback'}[-1];
}

sub _config  (SVN $self, hashref $c = undef) {
  if (defined $c) {
    $self->{config} = $self->{ctx}->config($c, $self->{pool});
  }
  return $self->{config};
}

sub _notify  (SVN $self, coderef $rv = undef) {
  if (defined $rv) {
    $self->{notify_callback} = [\$rv, $self->{ctx}->notify_baton($rv)];
  }
  return $$self{notify_callback}[-1];
}

{
  no strict qw/refs/;
  *{"SVN::Client::" . $_} = *{"_$_"}{CODE} for qw/log_msg config notify/;
}

# ctor

sub new :Sealed (__PACKAGE__ $class, AR $r) {
  shift, shift;
  $r = $r->main if $r and !$r->is_initial_req;
  state $initialized :shared;
  state $p = bless APR::Pool->new, "_p_apr_pool_t";
  eval{SVN::Core::utf_initialize($p)} if $r and !$initialized++;
  local $_ = $r ? $r->pool : $p;
  my _p_apr_pool_t $pool = bless $_, "_p_apr_pool_t";
  unshift @_, auth => $class->_create_auth($r, $pool), pool => $pool, config => {};
  my SVN $client;
  $client = $client->new(@_) or die "Can't create SVN::Client: $!";

  return bless {
    r      => $r,
    client => $client,
    pool   => $pool,
  }, $class;
}

# methods

sub add :Sealed (__PACKAGE__ $self, string $filename, boolean $recursive) {
  my SVN $svn = $self->client;
  normalize_svn_path $filename;
  $svn->add4($filename, $recursive ? $SVN::depth::infinity : $SVN::depth::empty, 0, 0, 1);
}

sub merge :Sealed (__PACKAGE__ $self, string $filename, string $target_path, integer $target_revision, boolean $dry_run) {
  ($filename, $target_path) = map dirname($_), $filename, $target_path if $filename !~ m#/$#;

  normalize_svn_path $filename, $target_path;

  my AR $r = $self->r;
  my SVN $svn = $self->client;
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

  utf8::decode $rv unless utf8::is_utf8 $rv;
  return $rv;

}

sub update :Sealed (__PACKAGE__ $self, string $filename, integer $depth) {
  normalize_svn_path $filename;
  my $dir = dirname $filename;
  my AR $r = $self->r;
  my SVN $svn = $self->client;
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

  utf8::decode $rv unless utf8::is_utf8 $rv;
  return $rv;
}

sub copy :Sealed (__PACKAGE__ $self, string $source, string $target) {
  normalize_svn_path $_ for $source, $target;
  my SVN $client = $self->client;
  my $rv = $client->copy($source, 'WORKING', $target);
  utf8::decode $rv unless ref $rv or utf8::is_utf8 $rv;
  return $rv;
}

sub move :Sealed (__PACKAGE__ $self, string $source, string $target) {
  shift, shift, shift;
  my ($force) = (@_, 1);
  normalize_svn_path $_ for $source, $target;
  my SVN $client = $self->client;
  my $rv = $client->move($source, undef, $target, $force);
  utf8::decode $rv unless ref $rv or utf8::is_utf8 $rv;
  return $rv;
}

sub delete :Sealed (__PACKAGE__ $self, string $filename) {
  shift, shift;
  my ($force) = (@_, 1);
  normalize_svn_path $filename;
  my SVN $client = $self->client;
  my $rv = $client->delete($filename, $force);
  utf8::decode $rv unless ref $rv or utf8::is_utf8 $rv;
  return $rv;
}

my @status;
eval '$status[$SVN::Wc::Status::' . "$_]=qq/\u$_/"
    for qw/modified conflicted added deleted unversioned
           normal ignored missing replaced obstructed/;

sub status :Sealed (__PACKAGE__ $self, string $filename) {
  shift, shift;
  my SVN $client = $self->client;
  my ($depth) = (@_, wantarray ? $SVN::Depth::immediates :$SVN::Depth::empty);
  my $prefix = $filename;
  $prefix =~ s![^/]+$!!;
  normalize_svn_path $filename;
  my @rv;
  my $callback = sub :Sealed {
    my $path = shift;
    my _p_svn_wc_status2_t $status = shift or return 0;
    $path =~ s!^\Q$prefix\E!!
      or $path = "./";
    utf8::decode $path unless utf8::is_utf8 $path;
    push @rv, [$path => $status[$_]] for $status->text_status;
    return 0;
  };

  $client->status4($filename, $SVN::Delta::INVALID_REVISION, $callback, $depth, (0) x 4, undef);
  return map @$_, @rv if wantarray;
  return $rv[0]->[1];
}

sub info :Sealed (__PACKAGE__ $self, string $filename, coderef $callback, $remote_revision = undef) {
  my SVN $client = $self->client;
  normalize_svn_path $filename;
  $client->info($filename, undef, $remote_revision, $callback, 0);
}

sub mkdir  (__PACKAGE__ $self, $url) {
  shift, shift;
  my SVN $client = $self->client;
  my ($make_parents) = (@_, 1);
  $url =~/(.*)/;
  $client->mkdir3($1, $make_parents, undef);
}

sub diff :Sealed (__PACKAGE__ $self, string $filename, boolean $recursive, integer $revision) {
  my SVN $client = $self->client;
  my $base_revision = $revision ? $revision - 1 : "BASE";
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
  utf8::decode $rv unless utf8::is_utf8 $rv;
  return $rv;
}

sub log :Sealed (__PACKAGE__ $self, string $filename, integer $prevision//="HEAD", integer $frevision//=1, integer $limit) {
  my SVN $svn = $self->client;
  $limit //= 1 if defined $prevision and $prevision ne "HEAD";
  $self->info($filename, sub {$filename = $_[1]->URL});
  s/-internal//, s/:4433// for $filename;
  my @rv;
  my @props = qw/svn:log svn:author svn:date/;
  local $@;
  eval {$svn->log5(
    $filename, undef, [[$prevision, $frevision]], $limit // 100, 1, 1, 0, \@props,
    sub :Sealed {
      my _p_svn_log_entry_t $log_entry = shift;
      my %cp2;
      @cp2{keys %{$log_entry->changed_paths2}} = map +{action => $_->action, text_modified => $_->text_modified, props_modified => $_->props_modified}, values %{$log_entry->changed_paths2};
      push @rv, [$log_entry->revision, \%cp2, grep {defined and utf8::decode($_); 1} @{$log_entry->revprops}{@props}];
    })};
  return \@rv;
}

sub AUTOLOAD {
  no strict 'refs';
  our $AUTOLOAD;
  my ($method_name) = (split /::/, $AUTOLOAD)[-1];
  return if $method_name eq "DESTROY";

  if (defined(my $client_method = $_[0]->client->can($method_name))) {
    *$AUTOLOAD = sub :Sealed (__PACKAGE__ $self) {
      shift;
      my AR $r = $self->r;
      my SVN $client = $self->client;
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
        splice @_, $file_idx, 1, $filename if @_ > 1;
      }
      my ($repos, $user, $lock) = $filename =~ m{^/x1/cms/wc(?:build)?/([^/]+)/([^-/]+)};
      $lock = get_lock("/x1/cms/locks/$repos-wc-$user") if defined $repos and defined $user;
      my $rv = $client_method->($client, @_); # SVN::Client::$client_method will push ctx and pool args.
      ref or (defined and utf8::decode $_) for ref($rv) eq "HASH" ? %$rv : ref($rv) eq "ARRAY" ? @$rv : $rv;
      return $rv;
    };
    goto &{*{$AUTOLOAD}{CODE}};
  }
  die "$AUTOLOAD(): method not found!";
}

if (undef) {
  local $@;
  eval {__PACKAGE__->new(undef)->log_msg(undef)};
  eval {__PACKAGE__->new(undef)->checkout(__FILE__)};
  warn $@;
  eval {__PACKAGE__->new(undef)->commit(__FILE__)};
  warn $@;
  eval {__PACKAGE__->new(undef)->cleanup(__FILE__)};
  warn $@;
  eval {__PACKAGE__->new(undef)->propget(__FILE__)};
  warn $@;
  eval {__PACKAGE__->new(undef)->propset(__FILE__)};
  warn $@;
  eval {__PACKAGE__->new(undef)->revert(__FILE__)};
  warn $@;
  undef $@;
}

1;
