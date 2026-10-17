#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  10-desktop.sh — escritorio de Core OS: experiencia tipo Windows 11
#  (barra de tareas abajo y centrada, menú de aplicaciones, bandeja del
#  sistema, tema oscuro) sobre GNOME.
#
#  La extensión que da el aspecto Windows es `dash-to-panel` (barra de tareas),
#  acompañada de `arc-menu` (menú de aplicaciones), `desktop-icons-ng` (iconos
#  del escritorio), `appindicator` (bandeja) y `caffeine`.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

EXT_DIR="/usr/share/gnome-shell/extensions"
DCONF_DIR="/etc/dconf/db/local.d"

# ---------------------------------------------------------------------------
# 1. Detección de las extensiones instaladas
# ---------------------------------------------------------------------------
# Se detectan los UUID reales en el sistema (en vez de escribirlos a mano) para
# que los ajustes sigan siendo válidos aunque cambie la versión del paquete.
log "Detectando extensiones de GNOME instaladas…"
ext_uuid() {
    local pattern="$1" dir
    for dir in "${EXT_DIR}"/*"${pattern}"*; do
        [ -d "$dir" ] || continue
        basename "$dir"
        return 0
    done
    return 1
}

enabled_extensions=()
declare -A wanted=(
    [dash-to-panel]="Barra de tareas (estilo Windows 11)"
    [arcmenu]="Menú de aplicaciones (estilo Windows)"
    [appindicator]="Bandeja del sistema"
    [desktop-icons-ng]="Iconos del escritorio"
    [ding]="Iconos del escritorio"
    [caffeine]="Evitar que se suspenda"
)
for pattern in dash-to-panel arcmenu appindicator desktop-icons-ng caffeine; do
    if uuid="$(ext_uuid "$pattern")"; then
        log "  · ${wanted[$pattern]:-$pattern}: ${uuid}"
        enabled_extensions+=("$uuid")
    else
        warn "no se encontró la extensión '${pattern}'"
    fi
done
[ "${#enabled_extensions[@]}" -gt 0 ] || die "no hay ninguna extensión de GNOME instalada"

# Array en formato dconf: ['uuid1', 'uuid2']
ext_list="["
for uuid in "${enabled_extensions[@]}"; do
    ext_list+="'${uuid}', "
done
ext_list="${ext_list%, }]"

# ---------------------------------------------------------------------------
# 2. Ajustes de GNOME en dconf (el grueso vive en el perfil de archiso)
# ---------------------------------------------------------------------------
log "Escribiendo los ajustes de escritorio en ${DCONF_DIR}/10-core-os-shell …"
run install -d -m 0755 "$DCONF_DIR"

cat > "${DCONF_DIR}/10-core-os-shell" <<EOF
# Core OS — shell de GNOME: extensiones activas y aplicaciones ancladas.
# Generado por customization/arch/scripts/10-desktop.sh
# (los UUID se detectan en el sistema en el momento del build).

[org/gnome/shell]
disable-user-extensions=false
enabled-extensions=${ext_list}
favorite-apps=['firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Software.desktop', 'core-os-panel.desktop', 'org.gnome.SystemMonitor.desktop', 'gnome-control-center.desktop']
welcome-dialog-last-shown-version='99.0'

# Ajustes por defecto del ratón y el touchpad (como en Windows).
[org/gnome/desktop/peripherals/touchpad]
tap-to-click=true
natural-scroll=false

[org/gnome/desktop/peripherals/mouse]
natural-scroll=false
EOF

# ---------------------------------------------------------------------------
# 3. Compilación de la base de datos dconf
# ---------------------------------------------------------------------------
if command -v dconf >/dev/null 2>&1; then
    log "Compilando la base de datos dconf (dconf update)…"
    run dconf update || die "dconf update falló: los ajustes del escritorio no se aplicarían"
else
    die "no se encontró el binario 'dconf' (falta el paquete dconf)"
fi

# ---------------------------------------------------------------------------
# 4. Utilidades propias del escritorio de Core OS
# ---------------------------------------------------------------------------
log "Creando las utilidades del escritorio de Core OS…"
PANEL_URL="http://localhost:${CORE_OS_WEB_DEMO_PORT}"

run install -d -m 0755 /usr/local/bin

# --- core-os-panel: abre el panel de administración en el navegador --------
cat > /usr/local/bin/core-os-panel <<EOF
#!/usr/bin/env bash
# Abre el panel de administración de Core OS.
set -euo pipefail
URL="\${CORE_OS_PANEL_URL:-${PANEL_URL}}"
for browser in firefox xdg-open chromium google-chrome-stable; do
    command -v "\$browser" >/dev/null 2>&1 && exec "\$browser" "\$URL"
done
echo "Panel de Core OS: \$URL"
EOF
run chmod 0755 /usr/local/bin/core-os-panel

# --- core-os-welcome: resumen de bienvenida -------------------------------
cat > /usr/local/bin/core-os-welcome <<EOF
#!/usr/bin/env bash
# Muestra la bienvenida de Core OS.
set -euo pipefail
VERSION="${CORE_OS_RELEASE}"
TITLE="Bienvenido a Core OS \${VERSION}"
MSG="Core OS \${VERSION} (${CORE_OS_BASE}) está listo.

• Panel de administración: ${PANEL_URL}
• Ajustes del sistema: gnome-control-center
• Terminal: Ctrl+Alt+T"

if command -v zenity >/dev/null 2>&1; then
    zenity --info --title="\${TITLE}" --width=480 --text="\${MSG}"
else
    printf '%s\n\n%s\n' "\${TITLE}" "\${MSG}"
fi
EOF
run chmod 0755 /usr/local/bin/core-os-welcome

# ---------------------------------------------------------------------------
# 5. Entradas del menú de aplicaciones
# ---------------------------------------------------------------------------
log "Creando los accesos directos de Core OS…"
run install -d -m 0755 /usr/share/applications

cat > /usr/share/applications/core-os-panel.desktop <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Panel de Core OS
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
Comment=Introducción a Core OS
Exec=core-os-welcome
Icon=core-os
Terminal=false
Categories=System;
StartupNotify=true
EOF

# ---------------------------------------------------------------------------
# 6. Accesos directos en el escritorio del usuario
# ---------------------------------------------------------------------------
for desktop_dir in /etc/skel/Desktop /etc/skel/Escritorio; do
    run install -d -m 0755 "$desktop_dir"
    run cp /usr/share/applications/core-os-panel.desktop "${desktop_dir}/Panel de Core OS.desktop"
    run chmod 0755 "${desktop_dir}/Panel de Core OS.desktop"
done

ok "10-desktop.sh completado"
