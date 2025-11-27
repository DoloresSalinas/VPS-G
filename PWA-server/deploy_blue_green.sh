#!/bin/bash
set -e

COLOR=${1:-blue}  
APP_NAME="vps-g-app"
NETWORK_NAME="app_appnet"
NGINX_ACTIVE_FILE="/home/deployer/app/nginx/ACTIVE"
NGINX_CONF="/etc/nginx/conf.d/app.conf"

echo "=== Desplegando color: $COLOR ==="

# Crear carpeta ACTIVE si no existe
mkdir -p $(dirname $NGINX_ACTIVE_FILE)

# Limpiar contenedores antiguos
docker rm -f ${APP_NAME}-blue ${APP_NAME}-green 2>/dev/null || true

# Crear red si no existe
docker network inspect ${NETWORK_NAME} >/dev/null 2>&1 || \
  docker network create -d bridge ${NETWORK_NAME}

# Construir contenedor
HOST_PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)
docker build -t ${APP_NAME}-${COLOR} ./PWA-server

# Levantar contenedor
docker run -d \
  --name ${APP_NAME}-${COLOR} \
  -p ${HOST_PORT}:3000 \
  --network ${NETWORK_NAME} \
  -e DATABASE_URL="$DATABASE_URL" \
  -e K6_CLOUD_TOKEN="$K6_CLOUD_TOKEN" \
  -e APP_COLOR="$COLOR" \
  ${APP_NAME}-${COLOR}

# Actualizar NGINX
sed -i "s|proxy_pass http://.*;|proxy_pass http://127.0.0.1:${HOST_PORT};|g" $NGINX_CONF

# Guardar color activo
echo $COLOR > $NGINX_ACTIVE_FILE

# Recargar NGINX
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
