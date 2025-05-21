#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  Instalador de snort‑agent — Versión vistosa ✨
# -------------------------------------------------------------
#  Conserva toda la lógica del instalador original, pero añade
#  una capa de salida coloreada y un resumen final al estilo
#  de R‑Snort3. No modifica la funcionalidad en absoluto.
# =============================================================

# ---------------------- Colores y símbolos -------------------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"
CHECK="${GREEN}✓${RESET}"
CROSS="${RED}✗${RESET}"
ARROW="${CYAN}▶${RESET}"
SEPARATOR="${MAGENTA}────────────────────────────────────────────${RESET}"

# ------------------------ Directorios ------------------------
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$BASE_DIR/scripts"

# ---------------- Comprobación de privilegios ----------------
if [[ $EUID -ne 0 ]]; then
  echo -e "${CROSS} Ejecuta este instalador como root"
  exit 1
fi

# Asegurarse de que los sub‑scripts son ejecutables
chmod +x "$SCRIPTS_DIR"/*.sh

# ------------------ Gestión del lock de dpkg -----------------
wait_for_dpkg_lock() {
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo -e "${YELLOW}[INFO] Esperando a que se libere el lock de dpkg/apt...${RESET}"
    sleep 5
  done
}

# -------------------- Ejecución de scripts -------------------
for s in \
  01_install_db.sh 02_configure_snort.sh 03_log_rotation.sh \
  04_setup_grafana.sh 05_setup_python_env.sh 06_install_services.sh \
  07_import_dashboard.sh; do
  echo -e "${SEPARATOR}"
  echo -e "${ARROW} Ejecutando ${BOLD}$s${RESET}"
  wait_for_dpkg_lock
  "$SCRIPTS_DIR/$s"
  echo -e "${CHECK} ${s} completado"
  sleep 0.3
done

# ====================== RESUMEN DEL SISTEMA ==================
#  (intentamos capturar la mayor parte de la info sin depender
#   de herramientas exóticas para mantener compatibilidad)
# =============================================================
HOSTNAME=$(hostname)
UPTIME=$(uptime -p | cut -d ' ' -f2-)
read -r RAM_USED RAM_TOTAL <<< $(free -h --si | awk '/Mem:/ {print $3, $2}')
SWAP_INFO=$(swapon --show --bytes --noheadings | wc -l)
if [[ $SWAP_INFO -gt 0 ]]; then
  SWAP_USED=$(swapon --show --human --noheadings | awk '{print $3"/"$4}')
else
  SWAP_USED="No"
fi
DISK_USAGE=$(df -h / | awk 'NR==2 {print $3" usados de "$2}')
CPU_MODEL=$(lscpu | grep -m1 "Model name" | sed 's/Model name:[[:space:]]*//')
ACTIVE_IF=$(ip -o -4 route show to default | awk '{print $5}' | head -n1)

# Intentar obtener la versión instalada de snort‑agent, si existe.
SNORT_AGENT_VERSION=$(dpkg -s snort-agent 2>/dev/null | awk -F': ' '/^Version/ {print $2}' || true)
[[ -z "$SNORT_AGENT_VERSION" ]] && SNORT_AGENT_VERSION="N/D"

print_summary() {
  echo -e "${SEPARATOR}"
  echo -e "${BLUE}${BOLD}[*] Resumen del sistema tras la instalación:${RESET}\n"
  printf " ${CYAN}📛  Hostname${RESET}:            %s\n" "$HOSTNAME"
  printf " ${CYAN}⏱   Uptime${RESET}:              %s\n" "$UPTIME"
  printf " ${CYAN}🧠  RAM usada${RESET}:           %s / %s\n" "$RAM_USED" "$RAM_TOTAL"
  printf " ${CYAN}🔄  Swap activa${RESET}:         %s\n" "$SWAP_USED"
  printf " ${CYAN}💾  Espacio raíz${RESET}:        %s\n" "$DISK_USAGE"
  printf " ${CYAN}⚙️   CPU${RESET}:                %s\n" "$CPU_MODEL"
  printf " ${CYAN}🤖  snort‑agent versión${RESET}:  %s\n" "$SNORT_AGENT_VERSION"
  printf " ${CYAN}🌐  Interfaz activa${RESET}:     %s\n" "$ACTIVE_IF"
  echo
}

print_summary

# ----------------------- Estado servicio ---------------------
if systemctl is-active --quiet snort-agent; then
  echo -e "${CHECK} snort‑agent está en ejecución en la interfaz: ${ACTIVE_IF}"
else
  echo -e "${CROSS} snort‑agent no se está ejecutando. Usa 'systemctl status snort-agent' para más detalles."
fi

# ------------------------ URLs finales -----------------------
IP=$(hostname -I | awk '{print $1}')

echo -e "${GREEN}${BOLD}✔ Instalación completada con éxito${RESET}"
echo -e "🌐 ${BOLD}API REST${RESET}  → ${BLUE}http://$IP:9000/docs${RESET}"
echo -e "📊 ${BOLD}Grafana${RESET}   → ${BLUE}http://$IP:3000${RESET}"

# =============================================================
#  Fin del instalador
# =============================================================
