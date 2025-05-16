#!/usr/bin/env bash
set -eEuo pipefail
trap 'echo "❌ Error en el script $0 en la línea $LINENO. Código $?."' ERR

# Log detallado
exec > >(tee -a /var/log/rsnort-grafana-setup.log) 2>&1

echo "[INFO] Iniciando configuración automática de Grafana…"

# Dependencias básicas
DEBIAN_FRONTEND=noninteractive \
apt-get install -y apt-transport-https software-properties-common wget jq curl net-tools

# --------------------------------------------------------------------
# 1. Descubrir IP y URLs
# --------------------------------------------------------------------
IP_LOCAL=$(ip -4 addr show scope global | awk '/inet/{print $2}' | cut -d/ -f1 | head -n1)
[[ -z "$IP_LOCAL" ]] && { echo "❌ No se pudo detectar la IP local"; exit 1; }

GRAFANA_LOCAL_URL="http://$IP_LOCAL:3000/api/health"
GRAFANA_PUBLIC_URL="http://$IP_LOCAL:3000"

echo "[INFO] IP local detectada:         $IP_LOCAL"
echo "[INFO] Comprobación interna en:    $GRAFANA_LOCAL_URL"
echo "[INFO] URL externa para el usuario $GRAFANA_PUBLIC_URL"

# --------------------------------------------------------------------
# 2. Instalar Grafana (si no existe)
# --------------------------------------------------------------------
if ! command -v grafana-server >/dev/null 2>&1; then
  wget -qO- https://packages.grafana.com/gpg.key | apt-key add -
  add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
  apt-get update -y
  apt-get install -y grafana
fi

GCONF="/etc/grafana/grafana.ini"

# --------------------------------------------------------------------
# 3. Configuración mínima en grafana.ini
#    (solo lo imprescindible para no duplicar claves en cada ejecución)
# --------------------------------------------------------------------
# Secciones que pueden faltar
grep -q '^\[security\]'       "$GCONF" || echo '[security]'        >> "$GCONF"
grep -q '^\[auth.anonymous\]' "$GCONF" || echo -e '\n[auth.anonymous]' >> "$GCONF"

# allow_embedding = true
sed -i '/^\[security\]/,/^\[/{s/^;*allow_embedding *= *.*/allow_embedding = true/; t}' "$GCONF"
grep -q '^allow_embedding' "$GCONF" || \
  sed -i '/^\[security\]/a allow_embedding = true' "$GCONF"

# auth.anonymous.enabled = true
sed -i '/^\[auth.anonymous\]/,/^\[/{s/^;*enabled *= *.*/enabled = true/; t}' "$GCONF"
grep -q '^enabled *= *true' "$GCONF" || \
  sed -i '/^\[auth.anonymous\]/a enabled = true' "$GCONF"

# Desactivar JWT si no existe la sección
grep -q '^\[auth.jwt\]' "$GCONF" || echo -e '\n[auth.jwt]\nenabled = false' >> "$GCONF"

# Permisos correctos
chown -R grafana:grafana /etc/grafana /var/lib/grafana /var/log/grafana

# --------------------------------------------------------------------
# 4. Credenciales de administrador sin ensuciar el INI
# --------------------------------------------------------------------
export GF_SECURITY_ADMIN_USER=admin
export GF_SECURITY_ADMIN_PASSWORD=admin

# --------------------------------------------------------------------
# 5. Arrancar Grafana
# --------------------------------------------------------------------
systemctl enable grafana-server
systemctl restart grafana-server

# --------------------------------------------------------------------
# 6. Esperar a que Grafana acepte peticiones
# --------------------------------------------------------------------
echo "[INFO] Esperando a que Grafana responda…"
START=$(date +%s)
TIMEOUT=600   # 10 minutos

until curl -sf --max-time 2 "$GRAFANA_LOCAL_URL" >/dev/null; do
  (( $(date +%s) - START > TIMEOUT )) && {
      echo "❌ Timeout: Grafana no respondió tras $TIMEOUT s"
      journalctl -u grafana-server --no-pager | tail -n 30
      exit 1
  }
  sleep 2
done
echo "✅ Grafana está accesible tras $(( $(date +%s) - START )) s"

# --------------------------------------------------------------------
# 7. Crear API-key (una sola vez)
# --------------------------------------------------------------------
API_KEY_FILE="/etc/rsnort-agent/grafana.token"
if [[ ! -f "$API_KEY_FILE" ]]; then
  echo "[INFO] Generando API-key…"
  KEY=$(curl -s -u admin:admin -H 'Content-Type: application/json' \
        -d '{"name":"rsnort-agent","role":"Admin"}' \
        "http://$IP_LOCAL:3000/api/auth/keys" | jq -r .key)

  [[ -z "$KEY" || "$KEY" == "null" ]] && {
      echo "❌ Error: no se pudo generar la API-key"
      exit 1
  }

  install -m600 /dev/null "$API_KEY_FILE"
  echo "$KEY" > "$API_KEY_FILE"
  echo "[INFO] API-key guardada en $API_KEY_FILE"
fi

# --------------------------------------------------------------------
# 8. Mensaje final
# --------------------------------------------------------------------
echo "✅ Configuración de Grafana completada correctamente."
echo "🌐 Accede desde tu navegador a:  $GRAFANA_PUBLIC_URL"
echo "🔑 API-key:                     $API_KEY_FILE"
