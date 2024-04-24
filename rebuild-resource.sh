#!/bin/bash

svn up www

for r in "$@";
do
  cp $r $r.tmp
  svn rm $r
  mv $r.tmp $r;
  svn add $r
done

svn commit -m "triggered rebuild: $@" www
