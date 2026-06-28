#!/usr/bin/bash
# USAGE: $0 [ooo]
: "${GIT_URL:=https://github.com/SunStarSys/www.iconoclasts.blog}"
: "${OFFLINE:=--offline}"

mkdir -p ~/.subversion
set -e
set -x
if [[ "${1:-}" == ooo ]]; then
  rm -rf trunk www
  ln -s ooo-trunk trunk
fi
for d in trunk www; do
  if [[ ! -d "$d" ]]; then
    mkdir "$d"
    chmod 0777 "$d"
    chmod +t "$d"
  fi
done

: "${TIMEOUT:=500}"

[[ -n "$LAUNCH_APACHE2" && -n "$MOZILLA" ]] && (
  sleep 3
  "$MOZILLA" http://localhost:8000/
) &

if [[ "${NO_DOCKER:-}" != 1 ]] && command -v docker >/dev/null 2>&1; then
  exec docker run ${LAUNCH_APACHE2+-p 127.0.0.1:8000:80} -t -v $(pwd):/src -v $HOME/.subversion:/home/ubuntu/.subversion -v $(pwd)/sites-enabled:/etc/apache2/sites-enabled -e GIT_URL="$GIT_URL" -e LANG="$LANG" -e LAUNCH_APACHE2="$LAUNCH_APACHE2" -e TIMEOUT="$TIMEOUT" --entrypoint= schaefj/linter zsh -c "zsh test.sh"
fi

if [ -n "$LAUNCH_APACHE2" ]; then
  APACHE_PID_FILE=/tmp/httpd.pid APACHE_RUN_DIR=/etc/apache2 APACHE_LOG_DIR=/tmp APACHE_RUN_USER=ubuntu APACHE_RUN_GROUP=ubuntu /usr/sbin/apache2 -k start
  node markdownd.js &
  timeout $TIMEOUT /src/watch.sh
  exit 0
fi

if [[ -d trunk/content ]]; then
  svn cleanup trunk || :
  svn up trunk || :
else
  git clone "$GIT_URL" trunk
fi

export WEBSITE="${GIT_URL##*/}" REPOS=public DEBUG_THREADS=1

(
  trap time EXIT
  node markdownd.js
) &

mkdir -p www/.build-log
perl -V | grep -i thread
sleep 3 #wait for markdown daemon to crank up
time timeout $TIMEOUT perl build_site.pl --source-base=trunk --target-base=www --revision=0 $OFFLINE | tee -a /dev/stderr | grep -q "Build done"
pkill -U $USER -f markdownd.js
wait
