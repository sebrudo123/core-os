#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  40-services.sh — servicios del sistema Core OS.
#
#  Se habilita lo mínimo imprescindible para que el escritorio, la red y los
#  servicios propios de Core OS funcionen tras el arranque (tanto en el medio
#  en vivo como en el sistema instalado, porque este se copia del medio).
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

enable() {
    local unit="$1"
    log "Habilitando ${unit}…"
    # Un servicio que no exista no debe tumbar la construcción: se avisa y se
    # sigue (las unidades propias de Core OS se habilitan donde se instalan).
    if ! systemctl enable "$unit"; then
        warn "no se pudo habilitar ${unit}"
    fi
}

# --- Escritorio ------------------------------------------------------------
enable gdm.service
enable accounts-daemon.service
enable systemd-timesyncd.service

# --- Red -------------------------------------------------------------------
enable NetworkManager.service
enable NetworkManager-dispatcher.service
enable wpa_supplicant.service    # lo usa NetworkManager para el Wi-Fi
enable bluetooth.service

# --- Audio -----------------------------------------------------------------
# pipewire/wireplumber se activan como servicios de usuario; se habilitan aquí
# para que arranquen solos en la sesión gráfica.
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null \
    || warn "no se pudieron habilitar los servicios de usuario de PipeWire"

# --- Impresión -------------------------------------------------------------
enable cups.socket

# --- Servicios propios de Core OS -----------------------------------------
# (los habilita cada script que instala su unidad: 45-web-demo.sh y
#  50-installer.sh, que se ejecutan después de este)

# --- Consolas --------------------------------------------------------------
enable serial-getty@ttyS0.service
enable getty@tty2.service

# --- Arranque gráfico por defecto -----------------------------------------
log "Estableciendo graphical.target como destino por defecto…"
run systemctl set-default graphical.target

# --- Mantenimiento ---------------------------------------------------------
enable fstrim.timer

ok "40-services.sh completado"
