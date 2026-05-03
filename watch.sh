#!/usr/bin/bash
cd /src/trunk/content
inotifywait -r -m -e modify,create,delete . | while read path action file; do
  perl /src/build_site.pl --source-base /src/trunk --target-base /src/www --dirqueue content/$path --revision 0
done
