#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-local-build}"
IMAGE_TAG="$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BASE="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_CONF_DIR="$APP_BASE/nginx/confs"
BLUE_CONF="$REPO_CONF_DIR/proxy.blue.conf"
GREEN_CONF="$REPO_CONF_DIR/proxy.green.conf"
ACTIVE_LINK="$REPO_CONF_DIR/active.conf"

echo "Desplegando imagen: $IMAGE_TAG"

if [ ! -f "$BLUE_CONF" ] || [ ! -f "$GREEN_CONF" ]; then
  echo "ERROR: Missing Nginx proxy templates in $REPO_CONF_DIR"
  echo "Expected: $BLUE_CONF and $GREEN_CONF"
  exit 1
fi

ACTIVE_COLOR="none"
if test -L "$ACTIVE_LINK"; then
  TARGET="$(readlink -f "$ACTIVE_LINK" || true)"
  if [[ "$TARGET" == "$BLUE_CONF" ]]; then
    ACTIVE_COLOR="blue"
  elif [[ "$TARGET" == "$GREEN_CONF" ]]; then
    ACTIVE_COLOR="green"
  fi
fi
if [ "$ACTIVE_COLOR" = "none" ] && sudo test -f "/etc/nginx/conf.d/vps-g.conf"; then
  if grep -q "127.0.0.1:3001" "/etc/nginx/conf.d/vps-g.conf"; then
    ACTIVE_COLOR="blue"
  elif grep -q "127.0.0.1:3002" "/etc/nginx/conf.d/vps-g.conf"; then
    ACTIVE_COLOR="green"
  fi
fi

# Decidir color de despliegue (el inactivo)
if [ "$ACTIVE_COLOR" == "blue" ]; then
  DEPLOY_COLOR="green"
  APP_PORT=3002
  CONTAINER_NAME="app-green"
elif [ "$ACTIVE_COLOR" == "green" ]; then
  DEPLOY_COLOR="blue"
  APP_PORT=3001
  CONTAINER_NAME="app-blue"
else
  DEPLOY_COLOR="blue"
  APP_PORT=3001
  CONTAINER_NAME="app-blue"
  ACTIVE_COLOR="none"
fi

echo "Activo: $ACTIVE_COLOR, desplegando: $DEPLOY_COLOR, contenedor: $CONTAINER_NAME, puerto: $APP_PORT"

# Login a GHCR (solo si no es local-build y tenemos credenciales)
if [[ "$IMAGE_TAG" != "local-build" ]] && [ -n "${REGISTRY_USER:-}" ] && [ -n "${REGISTRY_TOKEN:-}" ]; then
  echo "Iniciando sesión en GHCR..."
  echo "$REGISTRY_TOKEN" | docker login ghcr.io -u "$REGISTRY_USER" --password-stdin
fi

# Pull de la imagen (si viene de registry y no es local-build)
if [[ "$IMAGE_TAG" != "local-build" ]]; then
  echo "Descargando imagen: $IMAGE_TAG"
  docker pull "$IMAGE_TAG"
else
  echo "Usando imagen local-build, omitiendo pull"
fi

# Parar/eliminar previo del color de despliegue si existe
echo "Deteniendo contenedor existente: $CONTAINER_NAME"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Liberar el puerto objetivo si está ocupado por otro contenedor
echo "Verificando ocupación del puerto ${APP_PORT}..."
# Detecta cualquier contenedor (activo o detenido) que publique el puerto APP_PORT en IPv4 o IPv6
PORT_CONTAINERS=$(docker ps -a --format '{{.ID}} {{.Ports}}' | grep -E "(0\.0\.0\.0|:::):${APP_PORT}->" | awk '{print $1}')
if [ -n "$PORT_CONTAINERS" ]; then
  echo "Encontrados contenedores usando puerto ${APP_PORT}: $PORT_CONTAINERS. Eliminando..."
  for cid in $PORT_CONTAINERS; do
    docker rm -f "$cid" 2>/dev/null || true
  done
fi

# Run container con variables de entorno
echo "Iniciando nuevo contenedor: $CONTAINER_NAME"
docker run -d --name "$CONTAINER_NAME" --restart=unless-stopped \
  -p 127.0.0.1:${APP_PORT}:3001 \
  -e DATABASE_URL="${DATABASE_URL:-}" \
  -e K6_CLOUD_TOKEN="${K6_CLOUD_TOKEN:-}" \
  -e JWT_SECRET="${JWT_SECRET:-}" \
  -e PORT=3001 \
  -e APP_COLOR="${DEPLOY_COLOR}" \
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
  if [ $i -eq 30 ]; then
    echo "ERROR: Health check falló después de 30 intentos"
    docker logs "$CONTAINER_NAME" || true
    exit 1
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

echo "Actualizando configuración de Nginx..."
ln -sfn "$([ "$DEPLOY_COLOR" == "blue" ] && echo "$BLUE_CONF" || echo "$GREEN_CONF")" "$ACTIVE_LINK"
if ! sudo test -f "/etc/nginx/conf.d/vps-g.conf"; then
  # Crear una sola vez el include hacia el archivo activo dentro del repo
  sudo tee "/etc/nginx/conf.d/vps-g.conf" >/dev/null <<EOF
include $ACTIVE_LINK;
EOF
fi
sudo nginx -t
sudo systemctl reload nginx

echo "✅ Despliegue Blue-Green completado. Color activo: ${DEPLOY_COLOR}"

# Limpiar contenedor anterior (opcional)
if [ "$ACTIVE_COLOR" != "none" ]; then
  OLD_CONTAINER="app-${ACTIVE_COLOR}"
  echo "Contenedor anterior: $OLD_CONTAINER (se mantiene para rollback)"
  # Para eliminarlo automáticamente, descomenta:
  # docker stop "$OLD_CONTAINER" 2>/dev/null || true
  # docker rm "$OLD_CONTAINER" 2>/dev/null || true
fi

# Limpiar imágenes antiguas (opcional)
echo "Limpiando imágenes Docker no utilizadas..."
docker image prune -f 2>/dev/null || true
