#!/bin/bash
set -e
SERVICE=$1
RETRIES=${2:-30}
SLEEP=${3:-2}
for i in $(seq 1 $RETRIES); do
  if docker-compose exec -T "$SERVICE" node -e "require('http').get('http://127.0.0.1:3001/', r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" >/dev/null 2>&1; then
    echo "Servicio $SERVICE saludable"
    exit 0
  fi
  echo "Esperando al servicio $SERVICE... intento $i/$RETRIES"
  sleep "$SLEEP"
done
echo "Healthcheck falló para $SERVICE"
exit 1
