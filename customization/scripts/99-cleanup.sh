#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 99-cleanup.sh — reduce el tamaño de la imagen y elimina rastros de la build.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

log "Limpiando cachés de APT..."
run apt-get autoremove -y
run apt-get clean
run rm -rf /var/lib/apt/lists/*

log "Limpiando logs y temporales..."
run find /var/log -type f -exec truncate -s 0 {} \;
run rm -rf /tmp/* /var/tmp/*

log "Limpiando historial y estado de máquina (clonado limpio)..."
run rm -f /root/.bash_history
run rm -f /home/*/.bash_history
run truncate -s 0 /etc/machine-id

log "Eliminando claves SSH del host (se regeneran en el primer arranque)..."
run rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

log "99-cleanup.sh completado"
