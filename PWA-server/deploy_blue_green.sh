#!/bin/bash
# deploy_blue_green.sh
# Uso: ./deploy_blue_green.sh <blue|green>
set -e

# ---------------------------
# Configuración
# ---------------------------
COLOR=${1:-blue}  # color a desplegar (blue o green)
SERVICE_NAME="app-$COLOR"
NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE_FILE="nginx/ACTIVE"
PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)
TIMEOUT=120  # segundos para esperar a que el contenedor responda

echo "=== Desplegando color: $COLOR ==="

# ---------------------------
# Eliminar contenedores viejos para evitar conflictos
# ---------------------------
docker rm -f vps-g-app-blue vps-g-app-green 2>/dev/null || true

# ---------------------------
# Levantar contenedor del color activo
# ---------------------------
echo "-> Levantando contenedor $SERVICE_NAME..."
docker compose -p app up -d --build --remove-orphans $SERVICE_NAME

# ---------------------------
# Esperar a que el contenedor responda
# ---------------------------
echo "-> Esperando hasta $TIMEOUT segundos a que $SERVICE_NAME responda en puerto $PORT..."
END=$((SECONDS+TIMEOUT))
until curl -s http://127.0.0.1:$PORT >/dev/null 2>&1; do
  if [ $SECONDS -ge $END ]; then
    echo "❌ El contenedor $SERVICE_NAME no respondió después de $TIMEOUT segundos."
    exit 1
  fi
  sleep 1
done
echo "✅ Contenedor $SERVICE_NAME listo."

# ---------------------------
# Actualizar NGINX
# ---------------------------
echo "-> Actualizando NGINX para usar puerto $PORT..."
sudo sed -i "s|proxy_pass http://.*;|proxy_pass http://127.0.0.1:${PORT};|g" $NGINX_CONF

# ---------------------------
# Guardar color activo
# ---------------------------
mkdir -p $(dirname $ACTIVE_FILE)
echo $COLOR > $ACTIVE_FILE

# ---------------------------
# Recargar NGINX
# ---------------------------
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
