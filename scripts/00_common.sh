#!/usr/bin/env bash
set -euo pipefail

AGENT_STATE=/etc/rsnort-agent
mkdir -p "$AGENT_STATE"

# ID único por agente (persiste entre reinstalaciones)
AGENT_ID_FILE=$AGENT_STATE/agent.id
[[ -f $AGENT_ID_FILE ]] || uuidgen >"$AGENT_ID_FILE"
export AGENT_ID=$(cat "$AGENT_ID_FILE")

# Credenciales MariaDB (solo local)
DB_USER=rsnort
DB_PASS='cambio_me'          # ← si quieres, genera y almacena en vault
DB_NAME=rsnort_agent
DB_CNF=$AGENT_STATE/db.cnf   # usado por los scripts Python y mysql CLI

cat >"$DB_CNF" <<EOF
[client]
user=$DB_USER
password=$DB_PASS
database=$DB_NAME
host=127.0.0.1
EOF
chmod 600 "$DB_CNF"
