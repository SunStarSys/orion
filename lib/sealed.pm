# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :sealed subroutine attributes: use with care!
# (lots of segfaults in optimizer package, not workable with eg recursive subs)

package sealed;
use strict;
use warnings;
use optimizer ();
use B::Deparse ();

my %method;
my %valid_attrs = (sealed => 1);
use List::Util 'max';

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {

    my $cv_obj = B::svref_2object($rv);
    my @opstack = ($cv_obj->START->next);
    my ($pad_names, @pads) = $cv_obj->PADLIST->ARRAY;
    my @lexical_names = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;
    while (my $op = shift @opstack) {
      $$op and not $processed_op{$$op}++
        or next;

      if ($op->name eq "pushmark") {

        if ($op->next->name eq "padsv") {
	  $op = $op->next;
	  my $lex = $lexical_names[$op->targ];

	  if ($lex->TYPE->isa("B::HV")) {
	    $tweaked++;
            my $class = $lex->TYPE->NAME;

	    while ($op->next->name ne "entersub") {
              if ($op->next->name eq "method_named" and my $method = delete $method{${$op->next}})
	      {
		  defined and ($method = $_)
		    or die "Invalid method $method for $class"
		      for $class->can($method);
	        my $p_obj = B::svref_2object(sub {&import});
	        my $start = $p_obj->START->next->next;
	        my $methop = $op->next;
		my $targ;
		for my $aref (my @a = map $_->object_2svref, @pads) {
		    $targ //= max map scalar @$_, @a;
		    $aref->[$targ] =  $method;
	        }
	        my $rv2cv = bless $start->new($start->name, $start->flags), ref $start;
	        $rv2cv->padix($targ);
		$op->next($rv2cv);
		$rv2cv->next($methop->next);
	      }
	      $op = $op->next;
	    }

	    $op = $op->next;
	  }

	}
	$op = $op->next if $$op and $op->name ne "entersub";
	push @opstack, $op;
      }

      elsif ($op->isa("B::PMOP")) {
	push @opstack, $op->pmreplroot;	  
      }

      elsif ($op->can("first")) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	  push @opstack, $kid;
	}
	push @opstack, $op->next;
      }

      else {
        push @opstack, $op->next;
      }
    }
    if ($tweaked) {
      warn B::Deparse->new->coderef2text($rv), "\n";
    }
  }

  return grep !$valid_attrs{$_}, @attrs;
}

sub method_marker {
  my $op = shift;
  if ($op->can("name") and $op->name eq "method_named") {
      bless $op, "B::METHOP";
      my $method = ${$op->meth_sv->object_2svref};
      $method{$$op} = $method unless grep $method eq $_, qw/import unimport/;
  }
}

sub import {
  my $pkg = caller;
  no strict 'refs';
  *{"$pkg\::MODIFY_CODE_ATTRIBUTES"} = shift->can("MODIFY_CODE_ATTRIBUTES");
  optimizer->import('extend-c' => \&method_marker) unless shift;
}

sub unimport {
  optimizer::uninstall;
}

1;
