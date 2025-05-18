#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=/opt/snort/logs/live
SNORT_SERVICE=/etc/systemd/system/snort.service
SNORT_LUA=/usr/local/snort/etc/snort/snort.lua
BACKUP_DIR=/usr/local/snort/etc/snort/backup
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# ─────────────────────────── Selección de interfaz
# Buscar primero una interfaz UP + PROMISC
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | while read -r dev; do
  FLAGS=$(ip link show "$dev" | head -n1)
  if [[ "$FLAGS" == *UP* && "$FLAGS" == *PROMISC* ]]; then
    echo "$dev"
    break
  fi
done)

# Si no hay interfaz PROMISC, usar primera UP que no sea lo ni wlan*
if [[ -z "${IFACE:-}" ]]; then
  echo "⚠️  No se encontró ninguna interfaz en modo PROMISCUO. Se buscará una interfaz UP válida…"
  IFACE=$(ip -o -4 addr show up | awk '{print $2}' | grep -vE '^lo$|^wlan' | head -n1)
  if [[ -n "$IFACE" ]]; then
    echo "ℹ️  Se usará la interfaz alternativa: $IFACE"
  else
    echo "❌ No se encontró ninguna interfaz válida UP. Abortando."
    exit 1
  fi
else
  echo "✅ Se detectó interfaz UP + PROMISCUO: $IFACE"
fi

# ─────────────────────────── Configuración de Snort
echo "↻ Configurando Snort para usar interfaz $IFACE"

# Copia de seguridad si aún no existe una con la misma fecha
SNORT_BAK="$BACKUP_DIR/snort.lua.$(date +%s).bak"
cp -n "$SNORT_LUA" "$SNORT_BAK" && echo "📦 Copia de seguridad: $SNORT_BAK"

# Añadir bloque alert_json si NO está definido exactamente
if ! grep -q 'alert_json = {' "$SNORT_LUA"; then
  sed -i "/-- 7\\. configure outputs/a\\
alert_json = {\\
    file = true,\\
    limit = 50,\\
    fields = [[timestamp proto dir src_addr src_port dst_addr dst_port msg sid gid priority]]\\
}\\
" "$SNORT_LUA"
  echo "✅ Se añadió el bloque alert_json a snort.lua"
else
  echo "ℹ️  Ya existe una definición de alert_json en snort.lua, no se añadió nada"
fi

# ─────────────────────────── Servicio systemd
cat > "$SNORT_SERVICE" <<EOF
[Unit]
Description=Snort NIDS Daemon (R‑Snort agente)
After=network.target

[Service]
ExecStart=/usr/local/snort/bin/snort -q -c /usr/local/snort/etc/snort/snort.lua -i $IFACE -A alert_json -l $LOG_DIR
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
User=root
Group=root
LimitCORE=infinity
LimitNOFILE=65536
LimitNPROC=65536
PIDFile=/run/snort.pid

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable snort
systemctl restart snort
