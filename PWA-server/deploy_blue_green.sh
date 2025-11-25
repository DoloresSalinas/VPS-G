#!/bin/bash

set -e

echo "🚀 Iniciando despliegue Blue-Green..."

TARGET="$1"

if [ "$TARGET" != "blue" ] && [ "$TARGET" != "green" ]; then
    echo "❌ Uso incorrecto. Debes usar: ./deploy_blue_green.sh blue | green"
    exit 1
fi

echo "📦 Construyendo imagen para $TARGET..."
docker compose -f infra/docker-compose.yml build app-$TARGET

echo "🐳 Levantando contenedor $TARGET..."
docker compose -f infra/docker-compose.yml up -d app-$TARGET

echo "🩺 Ejecutando healthcheck..."
bash scripts/healthcheck.sh http://127.0.0.1:3001

echo "🔁 Cambiando Nginx al entorno $TARGET..."
bash nginx/switch-nginx.sh $TARGET

echo "🔄 Recargando Nginx..."
sudo service nginx reload

echo "🧹 Apagando la versión anterior..."
if [ "$TARGET" = "blue" ]; then
    docker compose -f infra/docker-compose.yml stop app-green || true
else
    docker compose -f infra/docker-compose.yml stop app-blue || true
fi

echo "✅ Despliegue Blue-Green completado correctamente en $TARGET"
