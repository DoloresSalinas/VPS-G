#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-ghcr.io/owner/repo:latest}"
# Normalize image reference to lowercase to satisfy GHCR requirements
IMAGE_TAG="$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]')"

# Paths Nginx - ajustados para tu estructura actual
NGINX_DIR="/home/azureuser/app/nginx"
ACTIVE_LINK="$NGINX_DIR/active.conf"
BLUE_CONF="$NGINX_DIR/blue.conf"
GREEN_CONF="$NGINX_DIR/green.conf"
UPSTREAM_DIR="/etc/nginx/conf.d"

# Preflight: ensure nginx files exist in app directory
if [ ! -f "$BLUE_CONF" ] || [ ! -f "$GREEN_CONF" ]; then
  echo "ERROR: Missing Nginx configuration files in $NGINX_DIR"
  echo "Expected: $BLUE_CONF and $GREEN_CONF"
  exit 1
fi

# Detección del color activo
ACTIVE_COLOR="none"
if [ -f "$ACTIVE_LINK" ]; then
  CURRENT_ACTIVE=$(basename $(readlink -f "$ACTIVE_LINK" 2>/dev/null || echo ""))
  if [[ "$CURRENT_ACTIVE" == "blue.conf" ]]; then
    ACTIVE_COLOR="blue"
  elif [[ "$CURRENT_ACTIVE" == "green.conf" ]]; then
    ACTIVE_COLOR="green"
  fi
fi

# Decidir color de despliegue (el inactivo)
if [ "$ACTIVE_COLOR" == "blue" ]; then
  DEPLOY_COLOR="green"
  APP_PORT=4001
  CONTAINER_NAME="app-green"
elif [ "$ACTIVE_COLOR" == "green" ]; then
  DEPLOY_COLOR="blue"
  APP_PORT=3001
  CONTAINER_NAME="app-blue"
else
  # Primer despliegue: usar blue
  DEPLOY_COLOR="blue"
  APP_PORT=3001
  CONTAINER_NAME="app-blue"
  ACTIVE_COLOR="none"
fi

echo "Activo: $ACTIVE_COLOR, desplegando: $DEPLOY_COLOR, contenedor: $CONTAINER_NAME, puerto: $APP_PORT"

# Login a GHCR (si se proporcionan credenciales)
if [ -n "${REGISTRY_USER:-}" ] && [ -n "${REGISTRY_TOKEN:-}" ]; then
  echo "$REGISTRY_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
fi

# Pull de la imagen (si viene de registry)
if [[ "$IMAGE_TAG" != local-build ]]; then
  docker pull "$IMAGE_TAG"
fi

# Parar/eliminar previo del color de despliegue si existe
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Run container con variables de entorno
docker run -d --name "$CONTAINER_NAME" --restart=unless-stopped \
  -p 127.0.0.1:${APP_PORT}:3001 \
  -e DATABASE_URL="${DATABASE_URL:-}" \
  -e K6_CLOUD_TOKEN="${K6_CLOUD_TOKEN:-}" \
  -e PORT=3001 \
  "$IMAGE_TAG"

# Health-check - ajustado para tu aplicación Node.js en puerto 3001
echo "Realizando health check en puerto ${APP_PORT}..."
for i in {1..30}; do
  if curl -f -s -o /dev/null --max-time 2 "http://127.0.0.1:${APP_PORT}" || 
     curl -f -s -o /dev/null --max-time 2 "http://127.0.0.1:${APP_PORT}/health" || 
     curl -f -s -o /dev/null --max-time 2 "http://127.0.0.1:${APP_PORT}/api/health"; then
    echo "Health-check OK en puerto ${APP_PORT}"
    break
  fi
  echo "Esperando servicio en puerto ${APP_PORT} (intento ${i}/30)..."
  sleep 3
done

# Verificar que el contenedor esté corriendo
if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "ERROR: El contenedor $CONTAINER_NAME no está corriendo"
  docker logs "$CONTAINER_NAME" || true
  exit 1
fi

# Actualizar configuración activa y alternar Nginx
echo "Actualizando configuración de Nginx..."

# Copiar configuración del color desplegado al active.conf
if [ "$DEPLOY_COLOR" == "blue" ]; then
  cp "$BLUE_CONF" "$ACTIVE_LINK"
else
  cp "$GREEN_CONF" "$ACTIVE_LINK"
fi

# Usar el script de switch de nginx si existe, o hacerlo manualmente
if [ -f "$NGINX_DIR/switch-nginx.sh" ]; then
  echo "Ejecutando script de switch de Nginx..."
  chmod +x "$NGINX_DIR/switch-nginx.sh"
  "$NGINX_DIR/switch-nginx.sh"
else
  echo "Alternando configuración de Nginx manualmente..."
  # Copiar la configuración activa a nginx
  sudo cp "$ACTIVE_LINK" "/etc/nginx/sites-available/default"
  
  # Test y recarga de nginx
  sudo nginx -t
  sudo systemctl reload nginx
fi

echo "✅ Despliegue Blue-Green completado. Color activo: ${DEPLOY_COLOR}"

# Limpiar contenedor anterior (opcional, comentado por seguridad)
if [ "$ACTIVE_COLOR" != "none" ]; then
  OLD_CONTAINER="app-${ACTIVE_COLOR}"
  echo "Contenedor anterior: $OLD_CONTAINER (puede ser eliminado manualmente si es necesario)"
  # docker stop "$OLD_CONTAINER" 2>/dev/null || true
  # docker rm "$OLD_CONTAINER" 2>/dev/null || true
fi

# Limpiar imágenes antiguas (opcional)
echo "Limpiando imágenes Docker no utilizadas..."
docker image prune -f 2>/dev/null || true