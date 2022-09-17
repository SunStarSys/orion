#!/usr/bin/bash
# USAGE: $0 [clean]

set -e
set -x
node markdownd.js &
if [[ "${1:-}" == clean ]]; then
  rm -rf trunk /tmp/www
fi
if [[ -d trunk ]]; then
  svn cleanup trunk
  svn up trunk
  sleep 3
else
  svn co https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com/trunk
fi
time perl -Ilib build_site.pl --source-base=trunk --target-base=/tmp/www
kill %1
