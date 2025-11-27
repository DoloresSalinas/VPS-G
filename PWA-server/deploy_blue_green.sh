#!/bin/bash
set -e
TARGET="$1"
if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  exit 1
fi
docker-compose build app-$TARGET
docker-compose up -d app-$TARGET
bash PWA-server/scripts/healthcheck.sh app-$TARGET
bash nginx/switch-nginx.sh $TARGET
docker-compose exec nginx nginx -s reload
if [ "$TARGET" = "blue" ]; then
  docker-compose stop app-green || true
else
  docker-compose stop app-blue || true
fi
exit 0
