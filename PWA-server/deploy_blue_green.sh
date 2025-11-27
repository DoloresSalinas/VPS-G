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
TIMEOUT=300
END=$((SECONDS+TIMEOUT))

# Asegurarse de que exista el archivo ACTIVE
mkdir -p $(dirname $ACTIVE_FILE)
if [ ! -s "$ACTIVE_FILE" ]; then
  echo "$COLOR" > "$ACTIVE_FILE"
fi

# Determinar puerto según color
PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)

echo "=== Desplegando color: $COLOR en puerto $PORT ==="

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
# Esperar hasta $TIMEOUT segundos a que la app responda
# ---------------------------
echo "-> Esperando hasta $TIMEOUT segundos a que app-$COLOR responda..."
while true; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "✅ app-$COLOR respondió correctamente!"
    break
  fi
  if [ $SECONDS -ge $END ]; then
    echo "❌ app-$COLOR no respondió después de $TIMEOUT segundos."
    exit 1
  fi
  sleep 1
done

# ---------------------------
# Actualizar NGINX
# ---------------------------
echo "-> Actualizando NGINX para usar puerto $PORT..."
sudo sed -i "s|proxy_pass http://.*;|proxy_pass http://127.0.0.1:${PORT};|g" $NGINX_CONF

# ---------------------------
# Guardar color activo
# ---------------------------
echo $COLOR > "$ACTIVE_FILE"

# ---------------------------
# Recargar NGINX
# ---------------------------
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
