#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 25-desktop-shell.sh — da a Core OS un escritorio propio con una experiencia
# tipo Windows 11: barra de tareas centrada abajo, botón "Inicio" (menú de
# aplicaciones), tema oscuro, iconos y accesos directos de Core OS.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

PANEL_URL="${CORE_OS_PANEL_URL:-http://localhost:8080}"

# ===========================================================================
# 1. Barra de tareas y shell (dconf de sistema, estilo Windows 11)
# ===========================================================================
log "Configurando la barra de tareas estilo Windows 11 (dash-to-dock)..."
run install -d -m 0755 /etc/dconf/db/local.d

cat > /etc/dconf/db/local.d/10-core-os-shell <<'EOF'
# Core OS — shell, barra de tareas y menú de aplicaciones (estilo Windows 11)

[org/gnome/shell]
# Apps "ancladas" a la barra de tareas / menú Inicio
favorite-apps=['core-os-panel.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.TextEditor.desktop', 'gnome-control-center.desktop', 'org.gnome.SystemMonitor.desktop', 'libreoffice-writer.desktop', 'libreoffice-calc.desktop']
disable-user-extensions=false
# Oculta el diálogo de bienvenida genérico de GNOME
welcome-dialog-last-shown-version='99.0'

# La barra de tareas de Core OS (extensión ubuntu-dock / dash-to-dock)
[org/gnome/shell/extensions/dash-to-dock]
dock-position='BOTTOM'
extend-height=false
height-fraction=0.9
autohide=false
intellihide=false
dock-fixed=true
show-show-apps-button=true
show-apps-at-top=true
show-mounts=false
show-trash=false
show-mounts-only-mounted=true
icon-size=44
max-icon-size=48
running-indicator-style='dots'
click-action='minimize'
scroll-action='cycle-windows'
background-opacity=0.85
transparency-mode='FIXED'
custom-theme-shrink=false
multi-monitor=true
preferred-monitor=-1

# Escritorio: sin iconos de sistema (estilo limpio)
[org/gnome/shell/extensions/ding]
show-home=false
show-trash=false

# Ratón/teclado como en Windows (scroll natural desactivado)
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=false

[org/gnome/desktop/peripherals/mouse]
natural-scroll=false
EOF

# Compila la base de datos dconf para que los ajustes se apliquen de verdad.
if command -v dconf >/dev/null 2>&1; then
  log "Compilando la base de datos dconf (dconf update)..."
  run dconf update || warn "dconf update no disponible (normal en chroot sin dbus)"
else
  warn "dconf no está disponible; se instalará con los paquetes del escritorio"
fi

# ===========================================================================
# 2. Utilidades de Core OS (panel, bienvenida y ajustes)
# ===========================================================================
log "Instalando utilidades de escritorio de Core OS..."

# --- core-os-panel: abre el panel de administración en el navegador --------
cat > /usr/bin/core-os-panel <<EOF
#!/usr/bin/env bash
# Abre el panel de administración de Core OS (Modo Demo Web).
set -euo pipefail
URL="\${CORE_OS_PANEL_URL:-${PANEL_URL}}"

for browser in xdg-open firefox chromium chromium-browser sensible-browser gnome-www-browser; do
  if command -v "\$browser" >/dev/null 2>&1; then
    exec "\$browser" "\$URL"
  fi
done

if command -v zenity >/dev/null 2>&1; then
  zenity --info --title="Core OS" --width=420 \\
    --text="El panel de Core OS está disponible en:\n\n<b>\$URL</b>\n\nÁbrelo desde un navegador."
else
  echo "Panel de Core OS: \$URL"
fi
EOF
run chmod 0755 /usr/bin/core-os-panel

# --- core-os-welcome: pantalla de bienvenida del primer arranque -----------
cat > /usr/bin/core-os-welcome <<'EOF'
#!/usr/bin/env bash
# Muestra un resumen de bienvenida a Core OS.
set -euo pipefail
VERSION="$(sed -n 's/^CORE_OS_RELEASE="\(.*\)"/\1/p' /etc/core-os/release 2>/dev/null || true)"
[ -n "$VERSION" ] || VERSION="1.0.0"

readonly TITLE="Bienvenido a Core OS ${VERSION}"
readonly MSG="Core OS ${VERSION} está listo.

• Panel de administración: http://localhost:8080
• Ajustes del sistema: gnome-control-center
• Terminal: Ctrl+Alt+T

Disfruta de tu sistema."

if command -v zenity >/dev/null 2>&1; then
  zenity --info --title="$TITLE" --width=480 --text="$MSG"
else
  echo "$TITLE"; echo; echo "$MSG"
fi
EOF
run chmod 0755 /usr/bin/core-os-welcome

# ===========================================================================
# 3. Entradas de menú (.desktop)
# ===========================================================================
log "Creando accesos directos en el menú de aplicaciones..."

cat > /usr/share/applications/core-os-panel.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Panel de Core OS
Name[en]=Core OS Panel
GenericName=Administración del sistema
Comment=Métricas, estado y control del sistema Core OS
Exec=core-os-panel
Icon=core-os
Terminal=false
Categories=System;Settings;Monitor;
Keywords=core-os;panel;admin;metricas;metrics;monitor;
StartupNotify=true
EOF

cat > /usr/share/applications/core-os-settings.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Ajustes de Core OS
Name[en]=Core OS Settings
Comment=Configura el sistema, el escritorio y los dispositivos
Exec=gnome-control-center
Icon=preferences-system
Terminal=false
Categories=System;Settings;
Keywords=ajustes;settings;configuracion;
StartupNotify=true
EOF

cat > /usr/share/applications/core-os-welcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Centro de bienvenida
Name[en]=Welcome Center
Comment=Introducción a Core OS
Exec=core-os-welcome
Icon=core-os
Terminal=false
Categories=System;
StartupNotify=true
EOF

cat > /usr/share/applications/core-os-version.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Acerca de Core OS
Name[en]=About Core OS
Comment=Información de la versión de Core OS
Exec=gnome-control-center info-overview
Icon=core-os
Terminal=false
Categories=System;Settings;
StartupNotify=true
EOF

# ===========================================================================
# 4. Accesos directos en el escritorio del usuario de la sesión Live
# ===========================================================================
for desktop_dir in Desktop Escritorio; do
  run install -d -m 0755 "/etc/skel/${desktop_dir}"
  run cp /usr/share/applications/core-os-panel.desktop \
    "/etc/skel/${desktop_dir}/Panel de Core OS.desktop"
  run cp /usr/share/applications/core-os-welcome.desktop \
    "/etc/skel/${desktop_dir}/Bienvenido a Core OS.desktop"
  run chmod 0755 "/etc/skel/${desktop_dir}/Panel de Core OS.desktop"
  run chmod 0755 "/etc/skel/${desktop_dir}/Bienvenido a Core OS.desktop"
done

log "25-desktop-shell.sh completado"
