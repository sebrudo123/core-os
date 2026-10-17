#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  99-cleanup.sh — limpieza final del medio en vivo.
#
#  La ISO se genera a partir de esta raíz, así que conviene no arrastrar cachés,
#  registros ni rastros del proceso de construcción.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

log "Vaciando la caché de paquetes…"
run rm -rf /var/cache/pacman/pkg/*
run pacman -Scc --noconfirm >/dev/null 2>&1 || true

log "Limpiando registros y archivos temporales…"
run mkdir -p /var/log/journal
run rm -rf /var/log/journal/* /var/log/*.log
run rm -rf /tmp/* /var/tmp/*
run rm -f /root/.bash_history "/home/${CORE_OS_LIVE_USER}/.bash_history" 2>/dev/null || true
run rm -rf /root/.cache "/home/${CORE_OS_LIVE_USER}/.cache" 2>/dev/null || true

# El identificador de máquina se regenera en cada arranque del sistema en vivo
# y en cada instalación (así no se clona entre equipos).
log "Eliminando /etc/machine-id…"
run rm -f /etc/machine-id /var/lib/dbus/machine-id

ok "99-cleanup.sh completado"
