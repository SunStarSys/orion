#!/usr/bin/bash
# USAGE: $0 [clean]
: "${SVN_URL:=https://vcs.sunstarsys.com/repos/svn/public/cms-sites/www.sunstarsys.com}"
set -e
set -x
if [[ "${1:-}" == clean ]]; then
  sudo rm -rf trunk www
fi
for d in trunk www; do
  if [[ ! -d "$d" ]]; then
    mkdir "$d"
    chmod 0777 "$d"
    chmod +t "$d"
  fi
done
if [[ "${NO_DOCKER:-}" != 1 ]] && command -v docker >/dev/null 2>&1; then
  exec docker run -t -v $(pwd):/src -e SVN_URL="$SVN_URL" --entrypoint= schaefj/linter zsh -c ". ~/.asdf/asdf.sh && zsh test.sh"
fi
(
  trap time EXIT
  node markdownd.js
) &
if [[ -d trunk/content ]]; then
  svn cleanup trunk || :
  svn up trunk || :
  sleep 3
else
  svn co "$SVN_URL"/trunk
  sleep 3
fi
time timeout 60 perl build_site.pl --source-base=trunk --target-base=www
pkill -U $USER -f markdownd.js
wait
