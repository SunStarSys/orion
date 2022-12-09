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

sub SVN::Pool::DESTROY {
  return 1;
}

sub new {
    my ($class, $r) = @_;
    shift; shift;
    my $pool = $r ? SVN::Pool->_wrap(${$r->pool}) : APR::Pool->new;
    unshift @_, auth => $class->_create_auth($r, $pool), pool => $pool;
    my $client = SVN::Client->new(@_) or die "Can't create SVN::Client: $!";
    return bless {
             r => $r,
             client => $client,
             pool => $pool,
    }, $class;
}

sub r       {shift->{r}}
sub client  {shift->{client}}
sub context {shift->{client}->{ctx}}
sub pool    {shift->{pool}}

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

  my $notifier = sub {
    my ($path, $action, undef, undef, $state) = @_;
    $path =~ s!^\Q$filename\E/?!!;
    push @{$dispatch{$state}}, $path and return 1 if exists $dispatch{$state};
    push @{$dispatch{$action}}, $path if exists $dispatch{$action};
  };
  local $_;
  my $ctx = $self->context;
  $svn->notify($notifier);

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
      undef,
      $ctx,
      $self->pool
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
      undef,
      $ctx,
      $self->pool
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

  my $notifier = sub {
    my ($path, $action, undef, undef, $state) = @_;
    $path =~ s!^\Q$filename\E/?!!;
    push @{$dispatch{$state}}, $path and return 1 if exists $dispatch{$state};
    push @{$dispatch{$action}}, $path if exists $dispatch{$action};
  };

  my $ctx = $self->context;
  $svn->notify($notifier);
  $depth = $SVN::Depth::infinity; # hard-coded
  my $revision = $svn->update3($filename, "HEAD", $depth, 1,  1, 0, $ctx, $self->pool);
  my $rv = "--- Updated '.' to HEAD:\n";
  $rv .= "C   $_\n" for @conflict;
  $rv .= "U   $_\n" for @update;
  $rv .= "A   $_\n" for @add;
  $rv .= "R   $_\n" for @restore;
  $rv .= "D   $_\n" for @delete;

  return $rv;
}

=pod

    my ($baton, $callbacks) = SVN::Core::auth_open_helper($self->_create_auth($r), $r->pool);
    my $config = SVN::Core::config_get_config(undef, $r->pool);
    my $repo_root;
    eval {
       my $cd_lock = SunStarSys::Orion::get_lock "$SunStarSys::Orion::BASE_DIR/locks/cwd-$$";
       chdir $dir;



       my $ra = SVN::Ra->new(url => $repo_root,
                            auth => $baton,
                          config => $config,
                            pool => $r->pool,
         auth_provider_callbacks => $callbacks);


#          $ra->notify( sub {
#          my ($path, $action) = @_;
#          $path =~ s!^\Q$dir/!!;
#          push @{$dispatch{$action}}, $path if exists $dispatch{$action};
#       });

       my ($reporter) = $ra->do_update(
       $SVN::Delta::INVALID_REVISION, basename($filename), 1,
            SVN::Delta::Editor->new(undef, $r->pool), $r->pool);
       $reporter->set_path('', 0, 1, undef, $r->pool);
       $reporter->finish_report($r->pool);
   };

    return add => \@add, delete => \@delete, restore => \@restore, update => \@update;

=cut

sub copy {
    my ($self, $source, $target) = @_;
    normalize_svn_path $_ for $source, $target;
    my $pool = $self->pool;
    my $ctx = $self->context;
    my $client = $self->client;
    $client->copy($source, 'WORKING', $target, $ctx, $pool);
}

sub move {
    my ($self, $source, $target, $force) = (@_, 1);
    normalize_svn_path $_ for $source, $target;
    my $pool = $self->pool;
    my $ctx = $self->context;
    my $client = $self->client;
    $client->move($source, 'HEAD', $target, $force, $ctx, $pool);
}

sub delete {
    my ($self, $filename, $force) = (@_, 1);
    normalize_svn_path $filename;
    my $pool = $self->pool;
    my $ctx = $self->context;
    my $client = $self->client;
    $client->delete($filename, $force, $ctx, $pool);
}

my @status;
eval '$status[$SVN::Wc::Status::' . "$_]=qq/\u$_/"
    for qw/modified conflicted added deleted unversioned
           normal ignored missing replaced obstructed/;

sub status :Sealed {
    my SunStarSys::SVN::Client $self = shift;
    my Apache2::RequestRec $r = $self->r;
    my $client = $self->client;
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

    $client->status4($filename, $SVN::Delta::INVALID_REVISION, $callback, $depth, (0) x 4, undef, $self->context, $pool);
    return map @$_, @rv if wantarray;
    return $rv[0]->[1];
}

sub info {
    my SunStarSys::SVN::Client $self = shift;
    my Apache2::RequestRec $r = $self->r;
    my SVN::Client $client = $self->client;
    my ($filename, $callback, $remote_revision) = @_;
    my $pool = $self->pool;
    my $ctx = $self->context;
    normalize_svn_path $filename;
    $client->info($filename, undef, $remote_revision // "WORKING", $callback, 0, $ctx, $pool);
}

sub mkdir {
    my ($self, $url, $make_parents) = (@_, 1);
    $url =~/(.*)/;
    my $pool = $self->pool;
    my $ctx = $self->context;
    $self->client->mkdir3($1, $make_parents, undef, $ctx, $pool);
}

sub diff {
    my ($self, $filename, $recursive) = (@_, 1);
    my Apache2::RequestRec $r = $self->r;
    normalize_svn_path $filename;
    open my $dfh, "+>", undef;
    open my $efh, "+>", undef;
    $self->client->diff([], $filename, 'BASE', $filename, 'WORKING', $recursive, 0, 1, $dfh, $efh, $self->context, $self->pool);
    seek $_, 0, SEEK_SET for $dfh, $efh;
    return join "", <$dfh>, <$efh>;
}

our $AUTOLOAD;

sub AUTOLOAD {
  no strict 'refs';
  my ($method_name) = (split /::/, $AUTOLOAD)[-1];
  return if $method_name eq "DESTROY";

  if (defined(my $client_method = $_[0]->client->can($method_name))) {
    *$AUTOLOAD = sub {
      my ($client, $r) = @{+shift}{qw/client r/};
      my $filename = $_[0];
      if (ref $filename) {
        $filename = $r->filename;
      }
      else {
        normalize_svn_path $filename;
        splice @_, 0, 1, $filename;
      }
      my ($repos, $user, $lock) = $filename =~ m{^/x1/cms/wc(?:build)?/([^/]+)/([^-/]+)};
      ($repos, $user) = $_[2] =~ m{^/x1/cms/wc/([^/]+)/([^-/]+)} unless defined $repos and defined $user;
      $lock = get_lock("/x1/cms/locks/$repos-wc-$user") if defined $repos and defined $user;
      $client_method->($client, @_);
    };
    goto &{*{$AUTOLOAD}{CODE}};
  }
  die "$AUTOLOAD(): method not found!";
}

eval {__PACKAGE__->new->log_msg(sub {})};
eval {__PACKAGE__->new->commit};
eval {__PACKAGE__->new->cleanup(__FILE__)};
1;
