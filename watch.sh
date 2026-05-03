#!/usr/bin/bash
cd /src/trunk/content
while true; do
  inotifywait -m -e modify,create,delete $(find . -type d) | while read path action dir; do
    perl /src/build_site.pl --source-base /src/trunk --target-base /src/www --dirqueue content/$path
done
