#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00_common.sh"

DASH_SRC=/opt/rsnort-agent/dashboard_intance.json
DGRAFANA=http://localhost:3000
API_KEY=$(cat /etc/rsnort-agent/grafana.token)

# 1. Crear datasource MariaDB si no existe
datasource_json=$(cat <<EOF
{
  "name": "Snort-MariaDB",
  "type": "mysql",
  "url": "127.0.0.1:3306",
  "database": "$DB_NAME",
  "user": "$DB_USER",
  "secureJsonData": { "password": "$DB_PASS" },
  "isDefault": true
}
EOF
)

curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
     -X POST $DGRAFANA/api/datasources \
     -d "$datasource_json" | jq .

# 2. Importar dashboard (el JSON ya usa ${DS_SNORT-MARIADB})
curl -s -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/json" \
     -X POST $DGRAFANA/api/dashboards/db \
     -d @"$DASH_SRC" | jq .
echo "📈 Dashboard importado en Grafana"
