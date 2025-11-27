#!/bin/bash
# deploy_blue_green.sh
# Uso: ./deploy_blue_green.sh <blue|green>
set -e

# ---------------------------
# Configuración
# ---------------------------
COLOR=${1:-blue}              # Color a desplegar (blue o green)
SERVICE_NAME="app-$COLOR"     # Nombre del servicio en Docker Compose
NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE_FILE="nginx/ACTIVE"
PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)
TIMEOUT=300 

echo "=== Desplegando color: $COLOR ==="

# ---------------------------
# Eliminar contenedores viejos
# ---------------------------
docker rm -f vps-g-app-blue vps-g-app-green 2>/dev/null || true

# ---------------------------
# Levantar contenedor del color activo
# ---------------------------
echo "-> Levantando contenedor $SERVICE_NAME..."
docker compose -p app up -d --build --remove-orphans $SERVICE_NAME

# ---------------------------
# Esperar hasta 300 segundos a que la app responda
# ---------------------------
echo "-> Esperando hasta 30 segundos a que app-$COLOR responda en puerto $PORT..."
for i in {1..30}; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "✅ app-$COLOR respondió correctamente!"
    break
  fi
  sleep 1
done

if [ "$STATUS" != "200" ]; then
  echo "❌ app-$COLOR no respondió después de 30 segundos."
  exit 1
fi

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
