# SPDX License Identifier: Apache License 2.0
#
# provides ithread-safe :Sealed subroutine attributes: use with care!
#
# Author: Joe Schaefer <joe@sunstarsys.com>

package sealed;
use v5.22;

use strict;
use warnings;

use B::Generate ();
use B::Deparse  ();

our $VERSION                    = v2.0.1;
our $DEBUG;

my %valid_attrs                 = (sealed => 1);
my $p_obj                       = B::svref_2object(sub {&tweak});

# B::PADOP (w/ ithreads) or B::SVOP
my $gv_op                       = $p_obj->START->next->next;

sub tweak ($\@\@\@) {
  my ($op, $lexical_varnames, $pads, $op_stack) = @_;
  my $tweaked                   = 0;

  if ($op->next->name eq "padsv") {
    $op                         = $op->next;
    my $type                    = $$lexical_varnames[$op->targ]->TYPE;
    my $class                   = $type->isa("B::HV") ? $type->NAME : undef;

    while (ref $op->next and $op->next->name ne "entersub") {

      if ($op->next->name eq "pushmark") {
	# we need to process this arg stack recursively
	splice @_, 0, 1, $op->next;
        ($op, my $t)            = &tweak;
        $tweaked               += $t;
      }

      elsif ($op->next->name eq "method_named" and defined $class) {
        my B::METHOP $methop    = $op->next;

        my ($method_name, $idx, $targ);

        if (ref($gv_op) eq "B::PADOP") {
          $targ                 = $methop->targ;

          # a little prayer
          $method_name          = $$pads[$idx++][$targ] while not defined $method_name;
        }
        else {
          $method_name          = ${$methop->meth_sv->object_2svref};
        }

        warn __PACKAGE__, ": compiling $class->$method_name lookup.\n"
          if $DEBUG;
        my $method              = $class->can($method_name)
          or die __PACKAGE__ . ": invalid lookup: $class->$method_name - did you forget to 'use $class' first?";

        # replace $methop

        my $gv                  = B::GVOP->new($gv_op->name, $gv_op->flags, $method);
        $gv->next($methop->next);
        $gv->sibparent($methop->sibparent);
        $gv->sibling($methop->sibling);
        $op->next($gv);

        if (ref($gv) eq "B::PADOP") {
          # reset mess B::GVOP->new made of current sub's (tweak's) pads
          (undef, $lexical_varnames, $pads, $op_stack) = @_;

          # reuse the $targ from the (passed) target pads
          $gv->padix($targ);
          $$pads[--$idx][$targ] = $method;
        }

        ++$tweaked;
      }
    }
    continue {
      $op = $op->next;
    }
  }

  push @$op_stack, $op->next;
  return ($op, $tweaked);
}

sub MODIFY_CODE_ATTRIBUTES {
  my ($class, $rv, @attrs) = @_;

  if ((not defined $DEBUG or $DEBUG ne "disabled") and grep $valid_attrs{+lc}, @attrs) {

    my $cv_obj                  = B::svref_2object($rv);
    my @op_stack                = ($cv_obj->START);
    my ($pad_names, @p)         = $cv_obj->PADLIST->ARRAY;
    my @pads                    = map $_->object_2svref, @p;
    my @lexical_varnames        = $pad_names->ARRAY;
    my %processed_op;
    my $tweaked;

    while (my $op = shift @op_stack) {
      ref $op and $$op and not $processed_op{$$op}++
        or next;

      $op->dump if defined $DEBUG and $DEBUG eq 'dump';

      if ($op->name eq "pushmark") {
	$tweaked               += tweak $op, @lexical_varnames, @pads, @op_stack;
      }
      elsif ($op->can("pmreplroot")) {
        push @op_stack, $op->pmreplroot, $op->next;
      }
      elsif ($op->can("first")) {
	for (my $kid = $op->first; ref($kid) && $$kid; $kid = $kid->sibling) {
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

  return grep !$valid_attrs{+lc}, @attrs;
}

sub import {
  $DEBUG                        = $_[1];
}

1;

__END__

=head1 sealed

Subroutine attribute for compile-time method lookups on its typed lexicals.

=over 4

=item Sample Usage

    use Apache2::RequestRec;
    use base 'sealed';

    sub handler :Sealed {
      my Apache2::RequestRec $r = shift;
      $r->content_type("text/html"); # compile-time method lookup.
    ...

=item C<import()> Options

    use sealed 'debug';   # warns about 'method_named' op tweaks
    use sealed 'deparse'; # additionally warns with the B::Deparse output
    use sealed 'dump';    # warns with the $op->dump during the tree walk
    use sealed 'disabled';# disables all CV tweaks
    use sealed;           # disables all warnings

=item BUGS

You may need to simplify your my named method call argument stack,
because this op-tree walker isn't as robust as it needs to be.
For example, any "branching" done in the target method's argument
stack, eg by using the '?:' ternary operator, will break this logic.

=item CAVEATS

Don't use this if you are writing a reusable OO module (on CPAN, say).
This module targets end-applications: virtual method lookups and
duck typing are core elements of any dynamic language's OO feature
design, and Perl is no different.  Look into XS if you want peak
performance in reusable OO methods you wish to provide.

=item See Also

L<https://www.sunstarsys.com/essays/perl7-sealed-lexicals>

=back
