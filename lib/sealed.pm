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

our $VERSION = v0.2.0;
our $DEBUG = 0;

my %valid_attrs = (sealed => 1);
my $p_obj = B::svref_2object(sub {&import});
my $start = $p_obj->START->next->next;

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {

    my $cv_obj = B::svref_2object($rv);
    my @opstack = ($cv_obj->START);
    my ($pad_names, @pads) = $cv_obj->PADLIST->ARRAY;
    my @lex_arr = map $_->object_2svref, @pads;
    my @lexical_names = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;

    while (my $op = shift @opstack) {
      $$op and not $processed_op{$$op}++
        or next;
      
      if ($op->name eq "pushmark") {

        if (index($op->next->name, "pad") == 0) {
	  $op = $op->next;
	  my $lex = $lexical_names[$op->targ];

	  if ($lex->TYPE->isa("B::HV")) {
	    ++$tweaked;
            my $class = $lex->TYPE->NAME;

	    while ($op->next->name ne "entersub") {
              if ($op->next->name eq "method_named") {
		my $methop = $op->next;
		my $targ = $methop->targ;
		my ($method_name, $idx);
		$method_name = $lex_arr[$idx++]->[$targ] while not defined $method_name;
		warn __PACKAGE__, ": compiling $class->$method_name lookup.\n";
		my $method = $class->can($method_name)
		    or die "Invalid lookup: $class->$method_name";
		$_->[$targ] = $method for @lex_arr;
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
	$op = $op->next if $$op and $op->name ne "entersub";
	unshift @opstack, $op;
      }

      elsif ($op->can("pmreplroot")) {
        push @opstack, $op->pmreplroot, $op->next;
      }
      
      elsif ($op->can("first")) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	  push @opstack, $kid;
	}
	unshift @opstack, $op->next;
      }

      else {
        unshift @opstack, $op->next;
      }
    }
    if ($DEBUG and $tweaked) {
      warn B::Deparse->new->coderef2text($rv), "\n";
    }
  }

  return grep !$valid_attrs{$_}, @attrs;
}

sub import {
  my $pkg = caller;
  no strict 'refs';
  *{"$pkg\::MODIFY_CODE_ATTRIBUTES"} = shift->can("MODIFY_CODE_ATTRIBUTES");
  $DEBUG = shift;
}


1;
