#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_common.sh"

GRAFANA=http://localhost:3000
AUTH="-u admin:admin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSON="$SCRIPT_DIR/../dashboard_intance.json"

log() { echo -e "\e[32m▶ $1\e[0m"; }

# Esperar a que Grafana responda
until curl -s "$GRAFANA/api/health" >/dev/null; do sleep 2; done

# 1) Crear datasource si no existe
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

# 2) Importar dashboard con mapping correcto
log "Importando dashboard"

WRAPPED=/tmp/dashboard_wrapped.json
jq -c --arg ds "Snort-MariaDB" '
  {
    dashboard: .,
    overwrite: true,
    inputs: [{
      name: "DS_SNORT-MARIADB",
      type: "datasource",
      pluginId: "mysql",
      value: $ds
    }]
  }
' "$JSON" > "$WRAPPED"

curl -f $AUTH -H"Content-Type: application/json" \
     -X POST $GRAFANA/api/dashboards/db \
     --data-binary @"$WRAPPED"

log "✔ Dashboard listo en Grafana"
