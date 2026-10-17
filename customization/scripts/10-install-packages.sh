#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 10-install-packages.sh — instala los paquetes de Core OS y purga los sobrantes.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

PACKAGES_FILE="${CUSTOMIZATION_DIR}/packages/packages.list"
REMOVE_FILE="${CUSTOMIZATION_DIR}/packages/remove.list"

log "Actualizando índices APT..."
run apt-get update -y

# --- Instalación -----------------------------------------------------------
mapfile -t PACKAGES < <(list_packages "$PACKAGES_FILE")
if [ "${#PACKAGES[@]}" -eq 0 ]; then
  die "no se encontraron paquetes en $PACKAGES_FILE"
fi
log "Instalando ${#PACKAGES[@]} paquetes de Core OS..."
run apt-get install -y --no-install-recommends "${PACKAGES[@]}"

# --- Purga -----------------------------------------------------------------
mapfile -t REMOVE < <(list_packages "$REMOVE_FILE")
if [ "${#REMOVE[@]}" -gt 0 ]; then
  log "Purgando ${#REMOVE[@]} paquetes no deseados..."
  # --allow-remove-essential no; ignoramos los que no existan con || true
  run apt-get purge -y "${REMOVE[@]}" || warn "algunos paquetes a purgar no existían"
fi

log "Limpieza de dependencias huérfanas..."
run apt-get autoremove -y

log "10-install-packages.sh completado"
