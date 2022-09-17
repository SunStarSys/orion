#!/usr/bin/bash
set -e
set -x
node markdownd.js &
if [[ -d trunk ]]; then
  svn cleanup trunk
  svn up trunk
else
  svn co https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.co
fi
time perl -Ilib build_site.pl --source-base=trunk --target-base=/tmp/www
kill %1
