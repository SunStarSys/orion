#!/bin/bash
cd /src/trunk/content || exit 1
inotifywait -r -m -e modify,create,delete . | while read -r path action file; do
  time perl /src/build_site.pl --source-base=/src/trunk --target-base=/src/www --dirqueue="content/$path" --revision=0
done
