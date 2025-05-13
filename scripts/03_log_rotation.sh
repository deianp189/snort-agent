#!/usr/bin/env bash
set -euo pipefail

ROTATE_CONF=/etc/logrotate.d/snort-alert-json

mkdir -p /var/log/snort/rotated
mkdir -p /var/log/snort/archived

# Configura logrotate
cat > "$ROTATE_CONF" <<'CONF'
/opt/snort/logs/live/alert_json.txt {
    size 200M
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    dateext
    olddir /var/log/snort/rotated
    create 640 root adm
}
CONF

# Configura backup diario
cat > /etc/cron.d/rsnort_backup <<'CRON'
0 1 * * * root /opt/rsnort-agent/scripts/backup_logs.sh
CRON
