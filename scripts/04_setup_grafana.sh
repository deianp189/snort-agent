#!/usr/bin/env bash
set -eEuo pipefail
trap 'echo "❌ Error en el script $0 en la línea $LINENO. Código $?."' ERR

# Registrar log para depuración automatizada
exec > >(tee -a /var/log/rsnort-grafana-setup.log) 2>&1

echo "[INFO] Iniciando configuración automática de Grafana..."

# Dependencias necesarias
apt-get install -y apt-transport-https software-properties-common wget jq curl net-tools

# --------------------------
# IPs y URLs
# --------------------------
# Interno: para validación y generación de API Key
GRAFANA_LOCAL_URL="http://localhost:3000/api/health"

# Externo: para acceso del usuario
IP_LOCAL=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
GRAFANA_PUBLIC_URL="http://$IP_LOCAL:3000"

echo "[INFO] IP local detectada: $IP_LOCAL"
echo "[INFO] Comprobación interna en: $GRAFANA_LOCAL_URL"
echo "[INFO] URL externa visible para el usuario: $GRAFANA_PUBLIC_URL"

# --------------------------
# Instalación de Grafana
# --------------------------
if ! command -v grafana-server >/dev/null 2>&1; then
  wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
  add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
  apt-get update -y
  apt-get install -y grafana
fi

GCONF="/etc/grafana/grafana.ini"

# --------------------------
# Configuración de grafana.ini
# --------------------------

# Admin credentials
grep -q "^admin_password" "$GCONF" || \
  sed -i '/^\[security\]/a admin_user = admin\nadmin_password = admin' "$GCONF"

# Anon access
if grep -q "^\[auth.anonymous\]" "$GCONF"; then
  sed -i '/^\[auth.anonymous\]/,/^\[/ s/^;*enabled = .*$/enabled = true/' "$GCONF"
else
  echo -e "\n[auth.anonymous]\nenabled = true" >> "$GCONF"
fi

# Embedding allowed
if grep -q "^\[security\]" "$GCONF"; then
  sed -i '/^\[security\]/,/^\[/ s/^;*allow_embedding = .*$/allow_embedding = true/' "$GCONF"
else
  echo -e "\n[security]\nallow_embedding = true" >> "$GCONF"
fi

# JWT off
if ! grep -q "^\[auth.jwt\]" "$GCONF"; then
  echo -e "\n[auth.jwt]\nenabled = false" >> "$GCONF"
fi

# Permisos correctos
chown -R grafana:grafana /etc/grafana /var/lib/grafana /var/log/grafana

# --------------------------
# Iniciar Grafana
# --------------------------
systemctl enable grafana-server
systemctl restart grafana-server

# --------------------------
# Esperar a que Grafana esté activo
# --------------------------
TRIES=0
MAX_TRIES=90  # 3 minutos

echo "[INFO] Esperando a que Grafana responda en $GRAFANA_LOCAL_URL..."

while true; do
  if curl -s --fail "$GRAFANA_LOCAL_URL" >/dev/null 2>&1; then
    echo "✅ Grafana está accesible internamente tras $((TRIES * 2)) segundos"
    break
  fi

  ((TRIES++))
  if [[ $TRIES -ge $MAX_TRIES ]]; then
    echo "❌ Timeout: Grafana no respondió tras $((TRIES * 2)) segundos"
    journalctl -u grafana-server --no-pager | tail -n 30
    exit 1
  fi
  sleep 2
done

# --------------------------
# Crear API Key si no existe
# --------------------------
API_KEY_FILE="/etc/rsnort-agent/grafana.token"
if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "[INFO] Generando API key de Grafana..."

  KEY=$(curl -s -u admin:admin -H "Content-Type: application/json" \
    -d '{"name":"rsnort-agent","role":"Admin"}' \
    "http://localhost:3000/api/auth/keys" | jq -r .key)

  if [[ -z "$KEY" || "$KEY" == "null" ]]; then
    echo "❌ Error: no se pudo generar la API key. Verifica credenciales o configuración de Grafana."
    exit 1
  fi

  echo "$KEY" > "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"
  echo "[INFO] API key guardada en: $API_KEY_FILE"
fi

# --------------------------
# Mensaje final
# --------------------------
echo "✅ Configuración de Grafana completada correctamente."
echo "🌐 Accede a Grafana desde otro dispositivo usando:"
echo "   → $GRAFANA_PUBLIC_URL"
echo "🔑 La API key generada está en: $API_KEY_FILE"
