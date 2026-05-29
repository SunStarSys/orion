#!/usr/bin/bash

if [[ "${NO_DOCKER:-}" != 1 ]] && command -v docker >/dev/null 2>&1; then
  exec docker run -v $(pwd):/src -v $(pwd)/sites-enabled:/etc/apache2/sites-enabled -e GIT_URL="$GIT_URL" -e LANG="$LANG" -e LAUNCH_APACHE2="$LAUNCH_APACHE2" -e TIMEOUT="$TIMEOUT" --entrypoint= schaefj/linter ./links2dotcfg.pl "$@"
fi

exec ./links2dotcfg.pl "$@"
