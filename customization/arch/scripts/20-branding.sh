#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  20-branding.sh — identidad de Core OS: nombre del sistema, /etc/os-release,
#  logotipos, fondos de pantalla y tema del menú de arranque (GRUB).
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

BRANDING="${CORE_OS_PAYLOAD}/branding"
LOGO_DIR="/usr/share/pixmaps/core-os"
ICON_ROOT="/usr/share/icons/hicolor"
GRUB_THEME_DIR="/boot/grub/themes/core-os"

# --- Identidad del sistema -------------------------------------------------
log "Escribiendo la identidad del sistema (/usr/lib/os-release)…"
cat > /usr/lib/os-release <<EOF
NAME="${CORE_OS_NAME}"
PRETTY_NAME="${CORE_OS_NAME} ${CORE_OS_RELEASE}"
ID=core-os
ID_LIKE=arch
BUILD_ID=rolling
VERSION_ID="${CORE_OS_RELEASE}"
VERSION="${CORE_OS_RELEASE}"
VERSION_CODENAME=core
ANSI_COLOR="38;2;56;189;248"
LOGO=core-os
HOME_URL="${CORE_OS_REPO_URL}"
DOCUMENTATION_URL="${CORE_OS_REPO_URL}#readme"
SUPPORT_URL="${CORE_OS_REPO_URL}/issues"
BUG_REPORT_URL="${CORE_OS_REPO_URL}/issues"
EOF
rm -f /etc/os-release
ln -sf ../usr/lib/os-release /etc/os-release

# Marcador de compatibilidad: algunas herramientas de Arch comprueban este
# fichero para saber que los paquetes son de Arch. La identidad visible sigue
# siendo Core OS.
: > /etc/arch-release
printf 'Core OS %s (Arch Linux)\n' "$CORE_OS_RELEASE" > /etc/core-os-release

# --- Hostname --------------------------------------------------------------
log "Estableciendo el nombre del equipo (${CORE_OS_LIVE_HOST})…"
printf '%s\n' "$CORE_OS_LIVE_HOST" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${CORE_OS_LIVE_HOST}.localdomain ${CORE_OS_LIVE_HOST}
EOF

# --- Mensajes de la consola de texto --------------------------------------
cat > /etc/issue <<EOF
${CORE_OS_NAME} ${CORE_OS_RELEASE} \\n \\l
EOF
cat > /etc/issue.net <<EOF
${CORE_OS_NAME} ${CORE_OS_RELEASE}
EOF

# --- Fondos de pantalla ----------------------------------------------------
if [ -d "${BRANDING}/wallpapers" ]; then
    log "Instalando los fondos de pantalla en ${CORE_OS_WALLPAPER_DIR}…"
    run install -d -m 0755 "$CORE_OS_WALLPAPER_DIR"
    shopt -s nullglob
    wallpapers=("${BRANDING}/wallpapers"/*)
    if [ "${#wallpapers[@]}" -gt 0 ]; then
        run cp -a "${wallpapers[@]}" "$CORE_OS_WALLPAPER_DIR/"
    else
        warn "no hay fondos de pantalla en ${BRANDING}/wallpapers"
    fi
    shopt -u nullglob
else
    warn "no se encontró ${BRANDING}/wallpapers"
fi

# --- Logotipo --------------------------------------------------------------
LOGO_SRC=""
for candidate in "${BRANDING}/logo/core-os.png" "${BRANDING}/logo/core-os.svg"; do
    [ -f "$candidate" ] && { LOGO_SRC="$candidate"; break; }
done

if [ -n "$LOGO_SRC" ]; then
    ext="${LOGO_SRC##*.}"
    log "Instalando el logotipo de Core OS (${ext})…"
    run install -d -m 0755 "$LOGO_DIR"
    run install -m 0644 "$LOGO_SRC" "${LOGO_DIR}/core-os.${ext}"
    for size in 16 24 32 48 64 128 256; do
        run install -d -m 0755 "${ICON_ROOT}/${size}x${size}/apps"
        run install -m 0644 "$LOGO_SRC" "${ICON_ROOT}/${size}x${size}/apps/core-os.${ext}"
    done
    # Icono de "About" del sistema (lo usa GNOME Control Center).
    run install -m 0644 "$LOGO_SRC" "/usr/share/pixmaps/core-os.${ext}"
else
    warn "no se encontró ${BRANDING}/logo/core-os.{png,svg}"
fi

# --- Tema del menú de arranque --------------------------------------------
# OJO: archiso BORRA el contenido de /boot de la raíz del medio en vivo (el
# kernel y el initramfs solo existen dentro de la ISO). Por eso el tema se
# guarda en /usr/share/core-os/grub-theme y es el INSTALADOR el que lo copia a
# /boot/grub/themes/core-os del sistema instalado.
if [ -f "${BRANDING}/grub/background.png" ]; then
    log "Instalando el tema de arranque en /usr/share/core-os/grub-theme…"
    run install -d -m 0755 /usr/share/core-os/grub-theme
    run install -m 0644 "${BRANDING}/grub/background.png" /usr/share/core-os/grub-theme/background.png
    [ -f "${BRANDING}/grub/logo.png" ] && \
        run install -m 0644 "${BRANDING}/grub/logo.png" /usr/share/core-os/grub-theme/logo.png
    run install -m 0644 "${BRANDING}/grub/theme.txt" /usr/share/core-os/grub-theme/theme.txt
else
    warn "no se encontró ${BRANDING}/grub/background.png"
fi

# --- Valores por defecto de GRUB (sistema instalado) ----------------------
log "Escribiendo /etc/default/grub…"
cat > /etc/default/grub <<EOF
# Core OS — valores por defecto del menú de arranque del sistema instalado.
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="${CORE_OS_NAME}"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_THEME="${GRUB_THEME_DIR}/theme.txt"
GRUB_DISABLE_OS_PROBER=false
GRUB_DISABLE_RECOVERY=true
# Fondo del menú (si el tema no estuviera disponible).
GRUB_BACKGROUND="${GRUB_THEME_DIR}/background.png"
EOF

ok "20-branding.sh completado"
