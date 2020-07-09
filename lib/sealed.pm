# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :sealed subroutine attributes: use with care!
# (lots of segfaults in optimizer package, not workable with recursive subs)

package sealed;
use strict;
use warnings;
use optimizer ();

my %method;
my %valid_attrs = (sealed => 1);

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if (grep exists $valid_attrs{$_}, @attrs) {

    my $cv_obj = B::svref_2object($rv);
    my @opstack = ($cv_obj->START);
    my ($pad_names, @pads) = $cv_obj->PADLIST->ARRAY;
    my @lexical_names = $pad_names->ARRAY;
    my %processed_op;

    while (my $op = shift @opstack) {

      next unless $$op and not $processed_op{$$op}++;

      if ($op->name eq "pushmark") {

        if ($op->next->name eq "padsv") {
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
	        my $p_obj = B::svref_2object(sub {&import});
	        my $start = $p_obj->START->next->next;
	        my $methop = $op->next;
	        my $targ   = $methop->targ;
	        for my $aref (map $_->object_2svref, @pads) {
	  	  $aref->[$targ] = *$sym{CODE};
	        }
	        my $rv2cv = bless $start->new($start->name, $start->flags), ref $start;
	        $rv2cv->targ($targ);
	        $rv2cv->padix($targ);
		$op->next($rv2cv);
		$rv2cv->next($methop->next);
	      }
	      $op = $op->next;
	    }
	    $op = $op->next;
	  }
	}
	$op = $op->next until $op->name eq "entersub";
	push @opstack, $op->next;
      }

      elsif ($op->isa("B::PMOP")) {
	# broken (USR2)
	push @opstack, $op->pmreplroot;	  
      }

      elsif ($op->can("first")) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	  push @opstack, $kid;
	}
      }

      else {
	push @opstack, $op->next;
      }
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

no strict 'refs';
sub import {
    my $pkg = caller;
    *{"$pkg\::MODIFY_CODE_ATTRIBUTES"} = shift->can("MODIFY_CODE_ATTRIBUTES");
    optimizer->import('extend-c' => \&method_marker) unless shift;
}

sub unimport {
    optimizer::uninstall;
}

1;
