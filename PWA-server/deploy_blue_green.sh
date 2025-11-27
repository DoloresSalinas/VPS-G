#!/bin/bash
# deploy_blue_green.sh
# Uso: ./deploy_blue_green.sh <blue|green>

set -e

COLOR=${1:-blue}  # color a desplegar (blue o green)
NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE_FILE="nginx/ACTIVE"

echo "=== Desplegando color: $COLOR ==="

# ⚡ Eliminar contenedores viejos para evitar conflictos
docker rm -f vps-g-app-blue vps-g-app-green 2>/dev/null || true

# Levantar el contenedor correspondiente
PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)
CONTAINER_NAME="vps-g-app-$COLOR"
docker compose -p app up -d --build --remove-orphans $CONTAINER_NAME

# ⚡ Esperar a que el backend responda antes de actualizar NGINX
echo "-> Esperando a que $COLOR esté disponible en el puerto $PORT..."
for i in $(seq 1 10); do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT || echo 000)
  if [ "$STATUS" -eq 200 ]; then
    echo "Backend listo!"
    break
  fi
  echo "Intento $i: backend no listo, esperando 3s..."
  sleep 3
done

# Actualizar NGINX para apuntar al color activo
echo "-> Actualizando NGINX para usar puerto $PORT..."
sudo sed -i "s|proxy_pass http://.*;|proxy_pass http://127.0.0.1:${PORT};|g" $NGINX_CONF

# Guardar color activo
mkdir -p $(dirname $ACTIVE_FILE)
echo $COLOR > $ACTIVE_FILE

# Recargar NGINX
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
