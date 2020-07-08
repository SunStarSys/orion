# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :sealed subroutine attributes: use with care!
# (lots of segfaults in optimizer package)

package sealed;
use strict;
use B::Generate;

my (%method, @code);
my %valid_attrs = (sealed => 1);

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {
    my $cv_obj = B::svref_2object($rv);
    my $op = $cv_obj->START;
    my ($pad_names, @pads) = $cv_obj->PADLIST->ARRAY;
    my @lexical_names = $pad_names->ARRAY;
    while ($op->name ne "leavesub") {
      if ($op->name eq "pushmark" and $op->next->name eq "padsv") {
	$op = $op->next;
	my $lex = $lexical_names[$op->targ];
	if ($lex->TYPE->isa("B::HV")) {
	  my $class = $lex->TYPE->NAME;
	  while ($op->next->name ne "entersub") {
	    if ($op->next->name eq "method_named" and exists $method{${$op->next}}) {
	      my $method = delete $method{${$op->next}};
	      no strict 'refs';
	      my $sym    = *{"$class\::$method"};
	      *$sym = $class->can($method) or die "WTF?: $method";
	      my $p_obj = B::svref_2object(my $s = eval "sub { &import }");
	      my $start = $p_obj->START->next->next;
	      my $methop = $op->next;
	      my $targ   = $methop->targ;
	      my $avref = $pads[0]->object_2svref;
	      $avref->[$targ] = *$sym{CODE};
	      my $newop = bless $start->new($start->name, $op->flags), ref $start;
	      $newop->targ($targ);
	      $newop->padix($targ);
	      $op->next($newop);
	      $newop->next($methop->next);
	      $newop->sibling($methop->sibling);
	    }
	    $op = $op->next;
	  }
	}
      }
      $op = $op->next;
    }
  }
  return grep !$valid_attrs{$_}, @attrs;
}

sub method_marker {
    my $op = shift;
    if ($op->can("name") and $op->name eq "method_named") {
	bless $op, "B::METHOP";
	my $meth_sv = $op->meth_sv;
	$method{$$op} = ${$meth_sv->object_2svref};
    }
}

no strict 'refs';

sub import {
    my $pkg = caller;
    *{"$pkg\::MODIFY_CODE_ATTRIBUTES"} = shift->can("MODIFY_CODE_ATTRIBUTES");
    require optimizer;
    optimizer->import('extend-c' => \&method_marker) unless shift;
}

sub unimport {
    require optimizer;
    optimizer->import('C');
}

1;
