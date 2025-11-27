#!/bin/bash
set -e
SERVICE=$1
RETRIES=${2:-30}
SLEEP=${3:-2}
for i in $(seq 1 $RETRIES); do
  if docker-compose exec -T "$SERVICE" wget -q -O - http://127.0.0.1:3001/ >/dev/null 2>&1; then
    exit 0
  fi
  sleep "$SLEEP"
done
exit 1
