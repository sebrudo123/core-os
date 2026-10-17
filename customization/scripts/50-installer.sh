#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 50-installer.sh — instala el asistente de instalación de Core OS
# (experiencia estilo Windows 11) que se muestra en la sesión en vivo.
#
# En el sistema instalado NO se muestra: el lanzador comprueba que estamos en
# el medio de instalación (casper/live) antes de arrancar.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

SETUP_SRC="${CUSTOMIZATION_DIR}/setup"
SETUP_DEST="/usr/lib/core-os/setup"

[ -d "$SETUP_SRC" ] || die "no se encontró el asistente en $SETUP_SRC"

log "Instalando el asistente de instalación de Core OS (estilo Windows 11)..."
run install -d -m 0755 "$SETUP_DEST"
run cp -a "$SETUP_SRC/." "$SETUP_DEST/"

# --- Lanzador (solo en el medio en vivo) -----------------------------------
cat > /usr/bin/core-os-setup <<'LAUNCHER'
#!/usr/bin/env bash
# El asistente solo se ejecuta desde el medio de instalación (live): la raíz
# del medio en vivo es overlayfs y además existe /cdrom. En el sistema
# instalado, no.
if ! findmnt -n -o FSTYPE / 2>/dev/null | grep -q overlay; then
  [ -d /cdrom ] || exit 0
fi
# La ventana (usuario) apunta al servicio en segundo plano (root) que instala.
# Renderizado por software: WebKit no dibuja bien en VM (llvmpipe) sin esto.
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1
export LIBGL_ALWAYS_SOFTWARE=1
exec /usr/bin/python3 /usr/lib/core-os/setup/core-os-setup.py --ui-only "$@"
LAUNCHER
run chmod 0755 /usr/bin/core-os-setup

# --- Servicio (root) que realiza la instalación ----------------------------
# Se activa en el medio en vivo (lo detecta el propio ExecStart).
UNIT_SRC="${CUSTOMIZATION_DIR}/systemd/core-os-setupd.service"
if [ -f "$UNIT_SRC" ]; then
  log "Instalando el servicio del instalador (core-os-setupd.service)..."
  run install -D -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-setupd.service
  run systemctl enable core-os-setupd.service || warn "no se pudo habilitar core-os-setupd.service"
else
  warn "no se encontró $UNIT_SRC"
fi

# --- Autostart en la sesión en vivo ----------------------------------------
run install -d -m 0755 /etc/xdg/autostart
cat > /etc/xdg/autostart/core-os-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Instalación de Core OS
Comment=Asistente de instalación de Core OS
Exec=/usr/bin/core-os-setup
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# --- Acceso manual desde el menú de aplicaciones ---------------------------
run install -d -m 0755 /usr/share/applications
cat > /usr/share/applications/core-os-setup.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Instalar Core OS
Comment=Instala Core OS en el disco
Exec=/usr/bin/core-os-setup
Icon=/usr/share/pixmaps/core-os/core-os.png
Terminal=false
Categories=System;
EOF

# --- Desactiva el instalador de Ubuntu (Core OS usa el suyo) ---------------
# (ubiquity, el asistente de primer arranque y el instalador nuevo 24.04)
run rm -f /etc/xdg/autostart/ubiquity.desktop \
          /etc/xdg/autostart/gnome-initial-setup.desktop 2>/dev/null || true
for pattern in '*provision*.desktop' '*ubiquity*.desktop' \
               '*initial-setup*.desktop' '*installer*.desktop'; do
  # shellcheck disable=SC2086
  run bash -c "rm -f /etc/xdg/autostart/${pattern}" 2>/dev/null || true
done

log "50-installer.sh completado"
