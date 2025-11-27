#!/bin/bash
set -e
TARGET="$1"
if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
  echo "Color inválido"
  exit 1
fi
echo "Construyendo app-$TARGET"
docker-compose build app-$TARGET
echo "Levantando app-$TARGET"
docker-compose up -d --remove-orphans app-$TARGET
echo "Verificando salud app-$TARGET"
bash PWA-server/scripts/healthcheck.sh app-$TARGET
echo "Levantando Nginx"
docker-compose up -d nginx
echo "Cambiando Nginx al entorno $TARGET"
bash nginx/switch-nginx.sh $TARGET
echo "Validando configuración de Nginx"
docker-compose exec nginx nginx -t
echo "Recargando Nginx"
docker-compose exec nginx nginx -s reload || docker-compose restart nginx
echo "Deteniendo versión anterior"
if [ "$TARGET" = "blue" ]; then
  docker-compose stop app-green || true
else
  docker-compose stop app-blue || true
fi
echo "Despliegue completado"
exit 0
