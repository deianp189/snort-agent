#!/usr/bin/env bash
set -eEuo pipefail
trap 'echo "❌ Error en el script $0 en la línea $LINENO. Código $?."' ERR
exec > >(tee -a /var/log/rsnort-grafana-setup.log) 2>&1

# ───────────────────────────────────────────────────────────────
# 0. Parámetros
# ───────────────────────────────────────────────────────────────
ADMIN_USER=admin
ADMIN_PASS=admin
SA_NAME="rsnort-agent"          # service-account
SA_TOKEN_NAME="rsnort-agent"    # nombre del token
TIMEOUT=600                     # s (10 min)
PORT=3000

# ───────────────────────────────────────────────────────────────
# 1. Dependencias básicas
# ───────────────────────────────────────────────────────────────
DEBIAN_FRONTEND=noninteractive \
apt-get install -y apt-transport-https software-properties-common \
                   wget jq curl net-tools

# ───────────────────────────────────────────────────────────────
# 2. IP y URLs
# ───────────────────────────────────────────────────────────────
IP_LOCAL=$(ip -4 addr show scope global | awk '/inet/{print $2}' | cut -d/ -f1 | head -n1)
[[ -z $IP_LOCAL ]] && { echo "❌ No se detectó IP local"; exit 1; }

BASE_URL="http://$IP_LOCAL:$PORT"
HEALTH_URL="$BASE_URL/api/health"

echo "[INFO] IP local:                 $IP_LOCAL"
echo "[INFO] Health-check interno en:  $HEALTH_URL"
echo "[INFO] URL externa:              $BASE_URL"

# ───────────────────────────────────────────────────────────────
# 3. Instalar Grafana (si no existe)
# ───────────────────────────────────────────────────────────────
if ! command -v grafana-server &>/dev/null; then
  wget -qO- https://packages.grafana.com/gpg.key | apt-key add -
  add-apt-repository -y "deb https://packages.grafana.com/oss/deb stable main"
  apt-get update -y
  apt-get install -y grafana
fi

GCONF=/etc/grafana/grafana.ini

# ───────────────────────────────────────────────────────────────
# 4. Ajustes mínimos (no duplicamos entradas)
# ───────────────────────────────────────────────────────────────
for section in '[security]' '[auth.anonymous]'; do
  grep -q "^$section" "$GCONF" || echo -e "\n$section" >> "$GCONF"
done

# allow_embedding = true
sed -i '/^\[security\]/,/^\[/{s/^;*allow_embedding *= *.*/allow_embedding = true/;t;}' "$GCONF"
grep -q '^allow_embedding' "$GCONF" || \
  sed -i '/^\[security\]/a allow_embedding = true' "$GCONF"

# auth.anonymous.enabled = true
sed -i '/^\[auth.anonymous\]/,/^\[/{s/^;*enabled *= *.*/enabled = true/;t;}' "$GCONF"
grep -q '^enabled *= *true' "$GCONF" || \
  sed -i '/^\[auth.anonymous\]/a enabled = true' "$GCONF"

# Desactivar JWT si falta la sección
grep -q '^\[auth.jwt\]' "$GCONF" || echo -e '\n[auth.jwt]\nenabled = false' >> "$GCONF"

chown -R grafana:grafana /etc/grafana /var/lib/grafana /var/log/grafana

# ───────────────────────────────────────────────────────────────
# 5. Reset de la contraseña admin (por si la cambiaron antes)
# ───────────────────────────────────────────────────────────────
systemctl stop grafana-server 2>/dev/null || true
grafana-cli admin reset-admin-password "$ADMIN_PASS" \
  || grafana-cli --homepath /usr/share/grafana admin reset-admin-password "$ADMIN_PASS"
echo "[INFO] Contraseña de $ADMIN_USER restablecida"

# ───────────────────────────────────────────────────────────────
# 6. Arranque y espera activa
# ───────────────────────────────────────────────────────────────
systemctl start grafana-server
echo "[INFO] Esperando a que Grafana responda…"
START=$(date +%s)
until curl -sf --max-time 2 "$HEALTH_URL" >/dev/null; do
  (( $(date +%s) - START > TIMEOUT )) && {
    echo "❌ Timeout: Grafana no respondió tras $TIMEOUT s"
    journalctl -u grafana-server --no-pager | tail -n 30
    exit 1
  }
  sleep 2
done
echo "✅ Grafana activo tras $(( $(date +%s) - START )) s"

# ───────────────────────────────────────────────────────────────
# 7. Crear Service-Account y obtener token
# ───────────────────────────────────────────────────────────────
TOKEN_FILE=/etc/rsnort-agent/grafana.token
mkdir -p "$(dirname "$TOKEN_FILE")"

get_sa_id () {
  curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
       "$BASE_URL/api/serviceaccounts/search?query=$SA_NAME" \
  | jq -r --arg n "$SA_NAME" '.serviceAccounts[] | select(.name==$n) | .id' \
  | head -n1
}

SA_ID=$(get_sa_id)

if [[ -z $SA_ID ]]; then
  SA_ID=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
          -H 'Content-Type: application/json' \
          -d "{\"name\":\"$SA_NAME\",\"role\":\"Admin\"}" \
          "$BASE_URL/api/serviceaccounts" \
        | jq -r .id)
  [[ -z $SA_ID || $SA_ID == null ]] && { echo "❌ No se pudo crear el Service Account"; exit 1; }
  echo "[INFO] Service-Account $SA_NAME creado con ID $SA_ID"
else
  echo "[INFO] Service-Account $SA_NAME ya existe (ID $SA_ID)"
fi

TOKEN=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
        -H 'Content-Type: application/json' \
        -d "{\"name\":\"$SA_TOKEN_NAME\",\"secondsToLive\":0}" \
        "$BASE_URL/api/serviceaccounts/$SA_ID/tokens" \
      | jq -r .key)

[[ -z $TOKEN || $TOKEN == null ]] && { echo "❌ No se pudo obtener el token"; exit 1; }

echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"
echo "[INFO] Token guardado en $TOKEN_FILE"

# ───────────────────────────────────────────────────────────────
# 8. Mensaje final
# ───────────────────────────────────────────────────────────────
echo "✅ Configuración de Grafana completada."
echo "🌐 Navega a:        $BASE_URL"
echo "🔑 Token SAT (file): $TOKEN_FILE"
