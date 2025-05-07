#!/usr/bin/env bash
    set -euo pipefail
    LOG_DIR=/opt/snort/logs/live
    SNORT_SERVICE=/etc/systemd/system/snort.service
    SNORT_LUA=/usr/local/snort/etc/snort/snort.lua
    BACKUP_DIR=/usr/local/snort/etc/snort/backup
    mkdir -p "$LOG_DIR" "$BACKUP_DIR"

    # Detectar interfaz de red (primera UP que no sea lo)
    IFACE=$(ip -o -4 addr show up primary scope global | awk '{print $2}' | head -n1)
    IFACE=${IFACE:-eno1}

    echo "↻ Configurando Snort para usar interfaz $IFACE"

    # Copia de seguridad
    cp -n "$SNORT_LUA" "$BACKUP_DIR/snort.lua.$(date +%s).bak" || true

    # Añadir bloque alert_json si no existe
    if ! grep -q "^alert_json" "$SNORT_LUA"; then
      sed -i "/-- 7\\. configure outputs/a\\
    alert_json = {\\
        file = true,\\
        limit = 50,\\
        fields = [[timestamp proto dir src_addr src_port dst_addr dst_port msg sid gid priority]]\\
    }\\
    " "$SNORT_LUA"
    fi


    # Crear nuevo servicio systemd
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
    PIDFile=/var/run/snort.pid

    [Install]
    WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable snort
    systemctl restart snort
