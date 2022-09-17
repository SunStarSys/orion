#!/usr/bin/bash
set -e
set -x
node markdownd.js &
rm -rf ./trunk /tmp/www
svn co https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com/trunk
time perl build_site.pl --source-base=trunk --target-base=/tmp/www
kill %1
