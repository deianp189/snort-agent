#!/usr/bin/env bash
set -euo pipefail

AGENT_STATE=/etc/rsnort-agent
mkdir -p "$AGENT_STATE"

# ID único del agente
AGENT_ID_FILE=$AGENT_STATE/agent.id
[[ -f $AGENT_ID_FILE ]] || uuidgen >"$AGENT_ID_FILE"
export AGENT_ID=$(cat "$AGENT_ID_FILE")

# Credenciales
DB_USER=rsnort
DB_PASS='cambio_me'
DB_NAME=rsnort_agent

# 1. db.cnf para cliente mysql
DB_CNF=$AGENT_STATE/db.cnf
cat >"$DB_CNF" <<EOF
[client]
user=$DB_USER
password=$DB_PASS
database=$DB_NAME
host=127.0.0.1
EOF
chmod 600 "$DB_CNF"

# 2. env.sh para uso en shell scripts con `source`
ENV_SH=$AGENT_STATE/env.sh
cat >"$ENV_SH" <<EOF
export RSNORT_DB_USERNAME="$DB_USER"
export RSNORT_DB_PASSWORD="$DB_PASS"
export RSNORT_DB_NAME="$DB_NAME"
EOF
chmod 644 "$ENV_SH"

# 3. env.service para systemd (sin export)
ENV_SYSTEMD=$AGENT_STATE/env.service
cat >"$ENV_SYSTEMD" <<EOF
RSNORT_DB_USERNAME=$DB_USER
RSNORT_DB_PASSWORD=$DB_PASS
RSNORT_DB_NAME=$DB_NAME
EOF
chmod 600 "$ENV_SYSTEMD"

# 4. Cargar variables en este mismo proceso
# shellcheck disable=SC1090
source "$ENV_SH"

# 5. Insertar en ~/.bashrc si no existe ya (solo si hay un usuario logueado)
if [[ -n "${SUDO_USER:-}" && -f "/home/$SUDO_USER/.bashrc" ]]; then
  BASHRC="/home/$SUDO_USER/.bashrc"
  if ! grep -Fxq "source $ENV_SH" "$BASHRC"; then
    echo "source $ENV_SH" >> "$BASHRC"
    echo "✅ Añadido source $ENV_SH a $BASHRC"
  else
    echo "ℹ️ Ya estaba presente en $BASHRC"
  fi
fi

# Confirmación
echo "🎉 Configuración completada."
echo "✔️  Archivo de conexión:     $DB_CNF"
echo "✔️  Entorno para shell:      $ENV_SH"
echo "✔️  Entorno para systemd:    $ENV_SYSTEMD"
echo "✔️  Variables actuales:"
echo "    RSNORT_DB_USERNAME=$RSNORT_DB_USERNAME"
echo "    RSNORT_DB_PASSWORD=$RSNORT_DB_PASSWORD"
echo "    RSNORT_DB_NAME=$RSNORT_DB_NAME"
