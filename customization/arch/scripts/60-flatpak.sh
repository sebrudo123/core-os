#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  60-flatpak.sh — repositorio de aplicaciones de Core OS.
#
#  Flatpak permite instalar aplicaciones actualizadas (Firefox, GIMP,
#  LibreOffice…) sin tocar los paquetes del sistema. El panel de Core OS usa
#  `flatpak` cuando está disponible.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

command -v flatpak >/dev/null 2>&1 || { warn "flatpak no está instalado; se omite"; exit 0; }

log "Añadiendo el repositorio Flathub al sistema…"
run flatpak remote-add --if-not-exists --system flathub \
    https://flathub.org/repo/flathub.flatpakrepo || warn "no se pudo añadir Flathub"

ok "60-flatpak.sh completado"
