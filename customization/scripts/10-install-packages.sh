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

# Intenta la instalación en bloque; si falla (p. ej. un paquete inexistente),
# cae a instalarlos uno a uno para no abortar toda la construcción.
if ! run apt-get install -y --no-install-recommends "${PACKAGES[@]}"; then
  warn "la instalación en bloque falló; se instalan uno a uno omitiendo errores"
  FAILED_PKGS=()
  for pkg in "${PACKAGES[@]}"; do
    if ! run apt-get install -y --no-install-recommends "$pkg"; then
      warn "no se pudo instalar: $pkg"
      FAILED_PKGS+=("$pkg")
    fi
  done
  if [ "${#FAILED_PKGS[@]}" -gt 0 ]; then
    warn "paquetes omitidos: ${FAILED_PKGS[*]}"
  fi
fi

# --- Purga -----------------------------------------------------------------
mapfile -t REMOVE < <(list_packages "$REMOVE_FILE")
if [ "${#REMOVE[@]}" -gt 0 ]; then
  log "Purgando ${#REMOVE[@]} paquetes no deseados..."
  # OJO (bug crítico ya sufrido): en Ubuntu `apt-get purge` activa el
  # autoremove automático y la imagen base marca como "auto" casi todo el
  # escritorio. Al purgar paquetes de los que dependen los metapaquetes
  # (ubuntu-desktop-minimal, ubuntu-minimal), apt elimina en cascada
  # gdm3, gnome-shell, ubuntu-session, xwayland... y el ISO se queda SIN
  # ESCRITORIO. Solución: marcar todo como "manual" (nada es huérfano) y
  # desactivar el autoremove en la propia purga.
  apt-mark showauto | xargs -r apt-mark manual || true
  run apt-get purge -y -o APT::Get::AutomaticRemove=false "${REMOVE[@]}" \
    || warn "algunos paquetes a purgar no existían"
fi

# --- Red de seguridad: el escritorio es imprescindible ----------------------
if [ ! -x /usr/bin/gnome-shell ] || [ ! -x /usr/sbin/gdm3 ]; then
  warn "el escritorio quedó incompleto; reinstalando lo esencial..."
  run apt-get install -y --no-install-recommends \
    gdm3 ubuntu-session gnome-shell gnome-session-bin gnome-shell-common xwayland \
    || warn "no se pudo reinstalar el escritorio"
fi
for bin in /usr/bin/gnome-shell /usr/sbin/gdm3 /usr/bin/gnome-session; do
  [ -e "$bin" ] || die "falta $bin: se ha eliminado el escritorio del ISO"
done

log "Limpieza de dependencias huérfanas..."
run apt-get autoremove -y

log "10-install-packages.sh completado"
