#!/usr/bin/env bash
set -euo pipefail


# Uso: ./switch-nginx.sh blue|green
TARGET=${1:-}
if [[ "$TARGET" != "blue" && "$TARGET" != "green" ]]; then
echo "Usage: $0 blue|green" >&2
exit 2
fi


NGINX_CONF_DIR=/etc/nginx/conf.d
REPO_DIR="$(cd "$(dirname "$0")" && pwd)/confs"


if [[ ! -d "$NGINX_CONF_DIR" ]]; then
echo "Warning: $NGINX_CONF_DIR does not exist. Are you running on WSL?" >&2
fi


if [[ "$TARGET" == "blue" ]]; then
SRC="$REPO_DIR/proxy.blue.conf"
else
SRC="$REPO_DIR/proxy.green.conf"
fi


sudo ln -sf "$SRC" "$NGINX_CONF_DIR/proxy.conf"


echo "Switched nginx config to $TARGET -> $SRC"


sudo nginx -t && sudo service nginx reload


echo "Nginx reloaded"