#!/usr/bin/env bash
set -euo pipefail

AGENT_ID_FILE=/etc/rsnort-agent/agent.id
DB_PATH=/var/lib/rsnort-agent/rsnort_agent.db

mkdir -p "$(dirname "$AGENT_ID_FILE")" /var/lib/rsnort-agent
if [[ ! -f "$AGENT_ID_FILE" ]]; then
  uuidgen > "$AGENT_ID_FILE"
fi
export AGENT_ID=$(cat "$AGENT_ID_FILE")
