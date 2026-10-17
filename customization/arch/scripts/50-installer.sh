#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  50-installer.sh — asistente de instalación de Core OS (estilo Windows 11).
#
#  Se compone de:
#    · una interfaz web (HTML/CSS/JS) mostrada a pantalla completa con WebKit2GTK,
#    · un servicio root (core-os-setupd) que expone la API de instalación en
#      127.0.0.1:8765 y hace la instalación REAL en el disco.
#
#  Solo se muestra en el MEDIO EN VIVO: el lanzador y el servicio comprueban
#  que existe /run/archiso (marca del sistema arrancado desde el ISO).
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

SETUP_SRC="${CORE_OS_PAYLOAD}/setup"
SETUP_DEST="/usr/lib/core-os/setup"

[ -d "$SETUP_SRC" ] || die "no se encontró el asistente en ${SETUP_SRC}"

log "Instalando el asistente en ${SETUP_DEST}…"
run install -d -m 0755 "$SETUP_DEST"
run cp -a "${SETUP_SRC}/." "$SETUP_DEST/"
run chmod 0755 "${SETUP_DEST}/core-os-setup.py"

# --- Lanzador (interfaz gráfica) ------------------------------------------
log "Creando /usr/local/bin/core-os-setup…"
cat > /usr/local/bin/core-os-setup <<'LAUNCHER'
#!/usr/bin/env bash
# Asistente de instalación de Core OS.
# Solo se ejecuta desde el medio en vivo (archiso crea /run/archiso).
[ -d /run/archiso ] || exit 0
# El renderizado de WebKit en una máquina virtual (llvmpipe) necesita estos
# ajustes para no quedarse en blanco.
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export GDK_BACKEND=x11
export LIBGL_ALWAYS_SOFTWARE=1
exec /usr/bin/python3 /usr/lib/core-os/setup/core-os-setup.py --ui-only "$@"
LAUNCHER
run chmod 0755 /usr/local/bin/core-os-setup

# --- Servicio root ---------------------------------------------------------
UNIT_SRC="${CORE_OS_PAYLOAD}/systemd/core-os-setupd.service"
[ -f "$UNIT_SRC" ] || die "falta ${UNIT_SRC}"
log "Instalando core-os-setupd.service…"
run install -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-setupd.service
run systemctl enable core-os-setupd.service

# --- Inicio automático en la sesión en vivo --------------------------------
log "Creando el arranque automático del asistente…"
run install -d -m 0755 /etc/xdg/autostart
cat > /etc/xdg/autostart/core-os-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Instalación de Core OS
Comment=Asistente de instalación de Core OS
Exec=/usr/local/bin/core-os-setup
Terminal=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=6
EOF

# --- Acceso manual desde el menú de aplicaciones ---------------------------
run install -d -m 0755 /usr/share/applications
cat > /usr/share/applications/core-os-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Instalar Core OS
Comment=Instala Core OS en el disco
Exec=/usr/local/bin/core-os-setup
Icon=core-os
Terminal=false
Categories=System;Utility;
EOF

ok "50-installer.sh completado"
