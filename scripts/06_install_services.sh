#!/usr/bin/env bash
    set -euo pipefail

    BASE_SRC="$(dirname "$0")/.."
    BASE_DST=/opt/rsnort-agent
    mkdir -p "$BASE_DST/python"

    cp -r "$BASE_SRC/python"/* "$BASE_DST/python"

    # Crear unidades systemd
    cat > /etc/systemd/system/rsnort-ingest.service <<'SERVICE'
    [Unit]
    Description=R‑Snort alert ingestion
    After=network.target snort.service

    [Service]
    ExecStart=/opt/rsnort-agent/venv/bin/python /opt/rsnort-agent/python/ingest_service.py
    Restart=always
    Environment=PYTHONUNBUFFERED=1

    [Install]
    WantedBy=multi-user.target
SERVICE

    cat > /etc/systemd/system/rsnort-api.service <<'SERVICE'
    [Unit]
    Description=R‑Snort agent REST API
    After=network.target snort.service

    [Service]
    WorkingDirectory=/opt/rsnort-agent/python
    ExecStart=/opt/rsnort-agent/venv/bin/uvicorn agent_api:app --host 0.0.0.0 --port 9000
    Restart=always

    [Install]
    WantedBy=multi-user.target
SERVICE

    cat > /etc/systemd/system/rsnort-metrics.service <<'SERVICE'
    [Unit]
    Description=R‑Snort metrics collection
    After=network.target snort.service

    [Service]
    Type=oneshot
    ExecStart=/opt/rsnort-agent/venv/bin/python /opt/rsnort-agent/python/metrics_timer.py
SERVICE

    cat > /etc/systemd/system/rsnort-metrics.timer <<'TIMER'
    [Unit]
    Description=Run metrics collection every 30 seconds

    [Timer]
    OnBootSec=30
    OnUnitActiveSec=30

    [Install]
    WantedBy=timers.target
TIMER

    systemctl daemon-reload
    systemctl enable rsnort-ingest.service rsnort-api.service rsnort-metrics.timer
    systemctl start rsnort-ingest.service rsnort-api.service rsnort-metrics.timer
