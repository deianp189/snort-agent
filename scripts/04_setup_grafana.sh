#!/usr/bin/env bash
set -euo pipefail

apt-get install -y apt-transport-https software-properties-common wget

# Instala grafana si no está presente
if ! command -v grafana-server >/dev/null 2>&1; then
  wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
  add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
  apt-get update -y
  apt-get install -y grafana
fi

GCONF="/etc/grafana/grafana.ini"

# Activar modo anónimo
if grep -q "^\[auth.anonymous\]" "$GCONF"; then
  sed -i '/^\[auth.anonymous\]/,/^\[/ s/^;*enabled = .*$/enabled = true/' "$GCONF"
else
  echo -e "\n[auth.anonymous]\nenabled = true" >> "$GCONF"
fi

# Activar embedding
if grep -q "^\[security\]" "$GCONF"; then
  sed -i '/^\[security\]/,/^\[/ s/^;*allow_embedding = .*$/allow_embedding = true/' "$GCONF"
else
  echo -e "\n[security]\nallow_embedding = true" >> "$GCONF"
fi

# Desactivar JWT si no está configurado
if ! grep -q "^\[auth.jwt\]" "$GCONF"; then
  echo -e "\n[auth.jwt]\nenabled = false" >> "$GCONF"
fi

# Asegurar permisos correctos
chown -R grafana:grafana /etc/grafana /var/lib/grafana /var/log/grafana

# Habilitar y reiniciar Grafana
systemctl enable grafana-server
systemctl restart grafana-server
