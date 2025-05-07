#!/usr/bin/env bash
set -euo pipefail
SRC=/var/log/snort/rotated
DEST=/var/log/snort/archived
mkdir -p "$DEST"
TS=$(date +%F)
if compgen -G "$SRC/*" > /dev/null; then
  tar -czf "$DEST/snort_logs_$TS.tar.gz" -C "$SRC" .
  rm -f "$SRC"/*
fi
# Borra archivos mayores a 30 días
find "$DEST" -type f -mtime +30 -delete
