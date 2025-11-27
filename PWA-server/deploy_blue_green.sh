#!/bin/bash
# deploy_blue_green.sh
# Uso: ./deploy_blue_green.sh <blue|green>

set -e

COLOR=${1:-blue}  # color a desplegar (blue o green)
APP_NAME="vps-g-app"
NETWORK_NAME="app_appnet"

echo "=== Desplegando color: $COLOR ==="

# 1️⃣ Limpiar contenedores antiguos
echo "-> Limpiando contenedores antiguos..."
docker ps -a -q --filter "name=${APP_NAME}" | xargs -r docker rm -f

# 2️⃣ Limpiar red vieja
docker network ls | grep ${NETWORK_NAME} | awk '{print $1}' | xargs -r docker network rm || true

# 3️⃣ Construir contenedor del color a desplegar
echo "-> Construyendo contenedor $COLOR..."
if [ "$COLOR" = "blue" ]; then
    HOST_PORT=3001
else
    HOST_PORT=3002
fi

docker build -t ${APP_NAME}-${COLOR} ./PWA-server

# 4️⃣ Levantar el contenedor
docker run -d \
  --name ${APP_NAME}-${COLOR} \
  -p ${HOST_PORT}:3000 \
  --network ${NETWORK_NAME} \
  -e DATABASE_URL="$DATABASE_URL" \
  -e K6_CLOUD_TOKEN="$K6_CLOUD_TOKEN" \
  -e APP_COLOR="$COLOR" \
  ${APP_NAME}-${COLOR}

# 5️⃣ Actualizar NGINX para apuntar al nuevo color
echo "-> Actualizando NGINX..."
NGINX_CONF="/etc/nginx/conf.d/app.conf"

if [ "$COLOR" = "blue" ]; then
    sed -i 's|proxy_pass http://.*;|proxy_pass http://127.0.0.1:3001; # blue|' $NGINX_CONF
else
    sed -i 's|proxy_pass http://.*;|proxy_pass http://127.0.0.1:3002; # green|' $NGINX_CONF
fi

# 6️⃣ Guardar color activo
echo $COLOR > /home/deployer/app/nginx/ACTIVE

# 7️⃣ Recargar NGINX
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
