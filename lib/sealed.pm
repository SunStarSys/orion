# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :sealed subroutine attributes: use with care!
#
# Author: Joe Schaefer <joe@sunstarsys.com>

package sealed;
use strict;
use warnings;
use B::Generate ();
use B::Deparse ();

our $VERSION = v0.4.0;
our $DEBUG = 0;

my %valid_attrs = (sealed => 1);
my $p_obj = B::svref_2object(sub {&import});
my $start = $p_obj->START->next->next;

sub tweak {
  my ($op, $lexical_names, $lexicals, $opstack) = @_;
  my $tweaked = 0;
  if (index($op->next->name, "padsv") == 0) {
    $op = $op->next;
    my $lex = $$lexical_names[$op->targ];
    if ($lex->TYPE->isa("B::HV")) {
      my $class = $lex->TYPE->NAME;
      while ($op->next->name ne "entersub") {
	if ($op->next->name eq "pushmark") {
	  splice @_, 0, 1, $op->next;
	  $tweaked += &tweak;
	}
	elsif ($op->next->name eq "method_named") {
	  my $methop = $op->next;
	  my $targ = $methop->targ;
	  my ($method_name, $idx);
	  $method_name = $$lexicals[$idx++]->[$targ] while not defined $method_name;
	  warn __PACKAGE__, ": compiling $class->$method_name lookup.\n";
	  my $method = $class->can($method_name)
	    or die "Invalid lookup: $class->$method_name";
	  $_->[$targ] = $method for @$lexicals;
	  my $rv2cv = bless $start->new($start->name, $start->flags), ref $start;
	  $rv2cv->padix($targ);
	  $op->next($rv2cv);
	  $rv2cv->next($methop->next);
	  $rv2cv->sibling($methop->sibling);
	}
	$op = $op->next;
      }
      $op = $op->next;
    }
  }
  unshift @$opstack, $op->next;
  return $tweaked;
}


sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {

    my $cv_obj = B::svref_2object($rv);
    my @op_stack = ($cv_obj->START);
    my ($pad_names, @pads) = $cv_obj->PADLIST->ARRAY;
    my @lex_arr = map $_->object_2svref, @pads;
    my @lexical_names = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;

    while (my $op = shift @op_stack) {
      $$op and not $processed_op{$$op}++
        or next;

      if ($op->name eq "pushmark") {
	  $tweaked += tweak($op, \@lexical_names, \@lex_arr, \@op_stack);
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
    if ($DEBUG and $tweaked) {
      warn B::Deparse->new->coderef2text($rv), "\n";
    }
  }

  return grep !$valid_attrs{$_}, @attrs;
}

sub import {
  $DEBUG = $_[1];
}

1;
