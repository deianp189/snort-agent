#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

if [[ $EUID -ne 0 ]]; then
  echo "⛔  Ejecuta este instalador como root"
  exit 1
fi

chmod +x "$SCRIPTS_DIR"/*.sh

wait_for_dpkg_lock() {
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "[INFO] Esperando a que se libere el lock de dpkg/apt..."
    sleep 5
  done
}

for s in 01_install_db.sh 02_configure_snort.sh 03_log_rotation.sh \
         04_setup_grafana.sh 05_setup_python_env.sh 06_install_services.sh \
         07_import_dashboard.sh; do
  echo "────────────────────────────────────────────"
  echo "▶ Ejecutando $s"
  wait_for_dpkg_lock
  "$SCRIPTS_DIR/$s"
done

echo "────────────────────────────────────────────"
echo "✅ Instalación completada con éxito"
echo "🌐 API REST → http://$(hostname -I | awk '{print $1}'):9000/docs"
echo "📊 Grafana  → http://$(hostname -I | awk '{print $1}'):3000"
