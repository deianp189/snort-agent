#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_common.sh"

GRAFANA=http://localhost:3000
AUTH="-u admin:admin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON="$SCRIPT_DIR/../dashboard_instance.json"
WRAPPED=/tmp/dashboard_wrapped.json

green()  { echo -e "\e[32m$1\e[0m"; }
yellow() { echo -e "\e[33m$1\e[0m"; }
red()    { echo -e "\e[31m$1\e[0m"; }

log()    { echo -e "▶ $1"; }

# Esperar a que Grafana esté listo
yellow "[INFO] Esperando a que Grafana esté accesible..."
TRIES=0
MAX_TRIES=30
until curl -s "$GRAFANA/api/health" >/dev/null; do
  sleep 2
  ((TRIES++))
  if [[ $TRIES -ge $MAX_TRIES ]]; then
    red "❌ Timeout: Grafana no respondió tras $((TRIES * 2)) segundos"
    exit 1
  fi
done
green "✔ Grafana está accesible"

echo

# Crear el datasource si no existe
if curl -s $AUTH "$GRAFANA/api/datasources/name/Snort-MariaDB" | jq -e '.name' >/dev/null 2>&1; then
  green "✔ Datasource Snort-MariaDB ya existe"
else
  yellow "➕ Creando datasource Snort-MariaDB..."
  cat >/tmp/ds.json <<EOF
{
  "name": "Snort-MariaDB",
  "type": "mysql",
  "access": "proxy",
  "url": "127.0.0.1:3306",
  "database": "$DB_NAME",
  "user": "$DB_USER",
  "secureJsonData": { "password": "$DB_PASS" },
  "isDefault": true
}
EOF
  curl -f $AUTH -H"Content-Type: application/json" \
       -X POST "$GRAFANA/api/datasources" \
       --data-binary @/tmp/ds.json
  green "✔ Datasource creado correctamente"
fi

echo

# Importar dashboard (elimina id y uid si existen)
yellow "📊 Importando dashboard..."
jq 'del(.id, .uid) | {dashboard: ., overwrite: true}' "$JSON" > "$WRAPPED"

IMPORT_RESPONSE=$(curl -sf $AUTH -H"Content-Type: application/json" \
     -X POST "$GRAFANA/api/dashboards/db" \
     --data-binary @"$WRAPPED")

# Extraer URL y nombre del dashboard
DASH_URL=$(echo "$IMPORT_RESPONSE" | jq -r '.url')
DASH_TITLE=$(echo "$IMPORT_RESPONSE" | jq -r '.slug')

green "✔ Dashboard importado correctamente"
echo
echo "🌐 Accede al dashboard en:"
echo "   ${GRAFANA}${DASH_URL}  ← (${DASH_TITLE})"
echo
