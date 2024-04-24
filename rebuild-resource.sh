#!/bin/bash
mkdir -p ~/.subversion
$PREFIX="docker run -t -v $(pwd):/src -v $HOME/.subversion:/home/ubuntu/.subversion --entrypoint= schaefj/linter"

$PREFIX svn up src

for r in "${@/trunk/src}";
do
  cp $r $r.tmp
  $PREFIX svn rm $r
  mv $r.tmp $r;
  $PREFIX svn add $r
done

$PREFIX svn commit -m "triggered rebuild" "${@/trunk/src}"
