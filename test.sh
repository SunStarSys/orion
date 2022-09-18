#!/usr/bin/bash
# USAGE: $0 [clean]
: "${SVN_URL:=https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com}"
set -e
set -x
node markdownd.js &
if [[ "${1:-}" == clean ]]; then
  rm -rf trunk www
fi
if [[ -d trunk ]]; then
  svn cleanup trunk
  svn up trunk
  sleep 3
else
  svn co "$SVN_URL"/trunk
fi
time perl -Ilib build_site.pl --source-base=trunk --target-base=www
kill %1
