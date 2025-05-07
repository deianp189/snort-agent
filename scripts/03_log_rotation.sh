#!/usr/bin/env bash
    set -euo pipefail
    ROTATE_CONF=/etc/logrotate.d/snort-alert-json
    mkdir -p /var/log/snort/rotated /var/log/snort/archived

    cat > "$ROTATE_CONF" <<'CONF'
    /opt/snort/logs/live/alert_json.txt {
        size 200M
        rotate 7
        copytruncate
        missingok
        notifempty
        compress
        dateext
        olddir /var/log/snort/rotated
    }
CONF

    # Backup diario a la 01:00
    cat > /etc/cron.d/rsnort_backup <<'CRON'
    0 1 * * * root /opt/rsnort-agent/scripts/backup_logs.sh
CRON
