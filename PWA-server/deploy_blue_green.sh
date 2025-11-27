#!/bin/bash
set -e

# ---------------------------
# Configuración
# ---------------------------
NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE_FILE="/home/azureuser/app/nginx/ACTIVE"
TIMEOUT=300
END=$((SECONDS+TIMEOUT))

# Variables de entorno para Docker Compose
export DATABASE_URL="$DATABASE_URL"
export K6_CLOUD_TOKEN="$K6_CLOUD_TOKEN"

echo "-> Variables de entorno:"
echo "DATABASE_URL=$DATABASE_URL"
echo "K6_CLOUD_TOKEN=$K6_CLOUD_TOKEN"

# ---------------------------
# Asegurarse de que exista el archivo ACTIVE
# ---------------------------
mkdir -p $(dirname "$ACTIVE_FILE")
if [ ! -s "$ACTIVE_FILE" ]; then
  echo "green" > "$ACTIVE_FILE"
fi

# ---------------------------
# Determinar color actual y próximo
# ---------------------------
CURRENT_COLOR=$(cat "$ACTIVE_FILE")
if [ "$CURRENT_COLOR" = "blue" ]; then
  COLOR="green"
  PORT=3002
else
  COLOR="blue"
  PORT=3001
fi
SERVICE_NAME="app-$COLOR"
OLD_SERVICE="app-$CURRENT_COLOR"

echo "=== Desplegando color: $COLOR (nuevo) en puerto $PORT ==="

# ---------------------------
# Levantar contenedor del nuevo color
# ---------------------------
echo "-> Levantando contenedor $SERVICE_NAME..."
docker compose -p app up -d --build --remove-orphans $SERVICE_NAME

# ---------------------------
# Esperar a que la app responda
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
  sleep 2
done

# ---------------------------
# Cambiar NGINX al nuevo contenedor
# ---------------------------
echo "-> Actualizando NGINX para usar puerto $PORT..."
sudo sed -i 's|proxy_pass http://127\.0\.0\.1:[0-9]\+;.*|proxy_pass http://127.0.0.1:'"$PORT"';|' $NGINX_CONF
sudo nginx -t && sudo systemctl reload nginx

echo "✅ NGINX apunta ahora al color $COLOR"

# ---------------------------
# Guardar color activo
# ---------------------------
echo $COLOR > "$ACTIVE_FILE"

# ---------------------------
# Borrar contenedor viejo
# ---------------------------
echo "-> Eliminando contenedor viejo $OLD_SERVICE..."
OLD_CONTAINER=$(docker compose -p app ps -q $OLD_SERVICE)
if [ -n "$OLD_CONTAINER" ]; then
  docker rm -f $OLD_CONTAINER
fi

echo "✅ Despliegue blue-green zero-downtime completado!"
docker ps
