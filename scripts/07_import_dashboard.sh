#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_common.sh"

GRAFANA=http://localhost:3000
AUTH="-u admin:admin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON="$SCRIPT_DIR/../dashboard_instance.json"
WRAPPED=/tmp/dashboard_wrapped.json

log() { echo -e "\e[32m▶ $1\e[0m"; }

# Esperar a que Grafana esté listo
until curl -s "$GRAFANA/api/health" >/dev/null; do sleep 2; done

# Crear el datasource si no existe
if curl -s $AUTH $GRAFANA/api/datasources/name/Snort-MariaDB | jq -e '.name' >/dev/null 2>&1; then
  log "Datasource Snort-MariaDB ya existe"
else
  log "Creando datasource Snort-MariaDB"
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
       -X POST $GRAFANA/api/datasources \
       --data-binary @/tmp/ds.json
fi

# Importar dashboard sin inputs
log "Importando dashboard"
jq -c '{
  dashboard: .,
  overwrite: true
}' "$JSON" > "$WRAPPED"

curl -f $AUTH -H"Content-Type: application/json" \
     -X POST $GRAFANA/api/dashboards/db \
     --data-binary @"$WRAPPED"

log "✔ Dashboard listo en Grafana"
