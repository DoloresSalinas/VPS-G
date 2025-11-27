#!/bin/bash
# deploy_blue_green.sh
# Uso: ./deploy_blue_green.sh <blue|green>

set -e

COLOR=${1:-blue}  # color a desplegar (blue o green)
NGINX_CONF="/etc/nginx/conf.d/app.conf"
ACTIVE_FILE="/home/deployer/app/nginx/ACTIVE"

echo "=== Desplegando color: $COLOR ==="

# ⚡ Eliminar contenedores antiguos para evitar conflictos
docker rm -f vps-g-app-blue vps-g-app-green 2>/dev/null || true

# Determinar el puerto según el color
PORT=$([ "$COLOR" = "blue" ] && echo 3001 || echo 3002)

# Actualizar NGINX para apuntar al color activo
echo "-> Actualizando NGINX para usar puerto $PORT..."
sed -i "s|proxy_pass http://.*;|proxy_pass http://127.0.0.1:${PORT};|g" $NGINX_CONF

# Guardar color activo
mkdir -p $(dirname $ACTIVE_FILE)
echo $COLOR > $ACTIVE_FILE

# Recargar NGINX
sudo systemctl reload nginx

echo "✅ Despliegue $COLOR completado!"
