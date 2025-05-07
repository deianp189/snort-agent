#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

if [[ $EUID -ne 0 ]]; then
  echo "⛔  Ejecuta este instalador como root"
  exit 1
fi

chmod +x "$SCRIPTS_DIR"/*.sh

for s in 01_install_db.sh 02_configure_snort.sh 03_log_rotation.sh 04_setup_grafana.sh 05_setup_python_env.sh 06_install_services.sh; do
  echo "▶ Ejecutando $s"
  "$SCRIPTS_DIR/$s"
done

echo "✅ Instalación completada"
echo "API REST → http://$(hostname -I | awk '{print $1}'):8080"
echo "Grafana    → http://$(hostname -I | awk '{print $1}'):3000"
