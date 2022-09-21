#!/usr/bin/bash
# USAGE: $0 [clean]
: "${SVN_URL:=https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com}"
set -e
set -x
if command -v docker >/dev/null 2>&1; then
  exec docker run -t -v $(pwd):/src -e SVN_URL="$SVN_URL" --entrypoint= schaefj/linter zsh -c ". ~/.asdf/asdf.sh && zsh test.sh $@"
fi

(trap time EXIT; node markdownd.js) &
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
time perl build_site.pl --source-base=trunk --target-base=www
pkill -U $USER -f markdownd.js
wait
