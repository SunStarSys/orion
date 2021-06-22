#!/usr/bin/env -S perl -Ilib
use strict;
use Benchmark ':all';
our ($x, $z);
$x = bless {}, "Foo";
$z = Foo->can("foo");
sub method {$x->foo}
sub class  {Foo->foo}
sub anon   {$z->($x)}
BEGIN {
  package Foo;
  use base 'sealed';
  use sealed 'deparse';
  sub foo  { shift }
  sub bar  { shift . "->::Foo::bar" }
}
sub func   {Foo::foo($x)}
BEGIN{@::ISA=('Foo')}
my main $y = $x;
sub sealed :Sealed {
    $y->foo();
}
sub also_sealed :Sealed {
    my main $a = shift;
    if ($a) {
        my Benchmark $bench;
        my $inner;
        return sub :Sealed {
            my Foo $b = $a;
            $b->foo($bench->cmpthese, $inner);
            $a->foo;
        };
    }
    $a->bar();
}
my %tests = (
    func => \&func,
    method => \&method,
    sealed => \&sealed,
    class => \&class,
    anon => \&anon,
);

print sealed(), "\n", also_sealed($y), "\n";
cmpthese 10_000_000, \%tests;
