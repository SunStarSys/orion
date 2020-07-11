# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :sealed subroutine attributes: use with care!
#
# Author: Joe Schaefer <joe@sunstarsys.com>

package sealed;

use strict;
use warnings;

use B::Generate ();
use B::Deparse  ();

our $VERSION       = v0.9.9;
our $DEBUG;

my %valid_attrs    = (sealed => 1);
my $p_obj          = B::svref_2object(sub {&tweak});
my B::PADOP $padop = $p_obj->START->next->next;

sub tweak {
  my ($op, $lexical_names, $pads, $op_stack) = @_;
  my $tweaked = 0;

  if ($op->next->name eq "padsv") {
    $op     = $op->next;
    my $lex = $$lexical_names[$op->targ];

    if ($lex->TYPE->isa("B::HV")) {
      my $class = $lex->TYPE->NAME;

      while ($op->next->name ne "entersub") {	  

	if ($op->next->name eq "pushmark") {
	  splice @_, 0, 1, $op->next;
	  ($op, my $t)         = &tweak;
	  $tweaked            += $t;
	}

	elsif ($op->next->name eq "method_named") {
	  my B::METHOP $methop = $op->next;
	  my $targ             = $methop->targ;

	  # a little prayer
	  my ($method_name, $idx);
	  $method_name         = $$pads[$idx++][$targ] while not defined $method_name;
	  warn __PACKAGE__, ": compiling $class->$method_name lookup.\n"
	      if $DEBUG;

	  my $method           = $class->can($method_name)
	    or die "Invalid lookup: $class->$method_name - did you forget to 'use $class' first?";
	  $$_[$targ]           = $method for @$pads; # bulletproof, blanket bludgeon

	  # replace $methop
	  my B::PADOP $rv2cv   = bless $padop->new($padop->name, $padop->flags), ref $padop;
	  $rv2cv->padix($targ);
	  $rv2cv->next($methop->next);
	  $rv2cv->sibling($methop->sibling);
	  $op->next($rv2cv);

	  $tweaked++;
	}

	$op = $op->next;
      }

      $op = $op->next;
    }

  }

  push @$op_stack, $op->next;
  return ($op, $tweaked);
}

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {

    my $cv_obj             = B::svref_2object($rv);
    my @op_stack           = ($cv_obj->START);
    my ($pad_names, @p)    = $cv_obj->PADLIST->ARRAY;
    my @pads               = map $_->object_2svref, @p;
    my @lexical_names      = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;

    while (my $op = shift @op_stack) {
      $$op and not $processed_op{$$op}++
        or next;

      if ($op->name eq "pushmark") {
	$tweaked += tweak($op, \@lexical_names, \@pads, \@op_stack);	  
      }
      elsif ($op->can("pmreplroot")) {
        push @op_stack, $op->pmreplroot, $op->next;
      }
      elsif ($op->can("first")) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	  push @op_stack, $kid;
	}
	unshift @op_stack, $op->next;
      }
      else {
        unshift @op_stack, $op->next;
      }

    }

    if (defined $DEBUG and $DEBUG eq "deparse" and $tweaked) {
      warn B::Deparse->new->coderef2text($rv), "\n";
    }

  }

  return grep !$valid_attrs{$_}, @attrs;
}

sub import {
  $DEBUG = $_[1];
}

1;

__END__

=head1 sealed

Subroutine attribute for compile-time method lookups on its typed lexicals.

=over 4

=item Sample Usage:

    use Apache2::RequestRec;
    use base 'sealed';

    sub handler :sealed {
      my Apache2::RequestRec $r = shift;
      $r->content_type("text/html"); # compile-time method lookup.
    ...

=item import() Options:

    use sealed 'debug';   # warns about 'method_named' op tweaks
    use sealed 'deparse'; # additionally warns with the B::Deparse output
    use sealed;           # disables all warnings

=item See Also:

    https://www.sunstarsys.com/essays/perl7-sealed-lexicals

=back
