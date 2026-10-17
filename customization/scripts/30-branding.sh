#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 30-branding.sh — identidad visual y de sistema de Core OS.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

BRANDING_DIR="${CUSTOMIZATION_DIR}/branding"
WALLPAPER_DIR="/usr/share/backgrounds/core-os"
LOGO_DIR="/usr/share/pixmaps/core-os"
ICON_DIR="/usr/share/icons/hicolor"

run install -d -m 0755 "$WALLPAPER_DIR" "$LOGO_DIR"

# --- Wallpapers -------------------------------------------------------------
if [ -d "${BRANDING_DIR}/wallpapers" ]; then
  shopt -s nullglob
  wallpapers=("${BRANDING_DIR}/wallpapers"/*)
  if [ "${#wallpapers[@]}" -gt 0 ]; then
    log "Copiando ${#wallpapers[@]} wallpapers a $WALLPAPER_DIR"
    run cp -a "${wallpapers[@]}" "$WALLPAPER_DIR/"
  else
    warn "branding/wallpapers está vacío (añade tus PNG/JPG)"
  fi
  shopt -u nullglob
fi

# --- Logo -------------------------------------------------------------------
# Se acepta PNG (preferido) o SVG.
LOGO_SRC=""
for candidate in "${BRANDING_DIR}/logo/core-os.png" "${BRANDING_DIR}/logo/core-os.svg"; do
  if [ -f "$candidate" ]; then LOGO_SRC="$candidate"; break; fi
done

if [ -n "$LOGO_SRC" ]; then
  logo_ext="${LOGO_SRC##*.}"
  log "Instalando logo de Core OS (${logo_ext})..."
  run install -D -m 0644 "$LOGO_SRC" "${LOGO_DIR}/core-os.${logo_ext}"
  for size in 16 32 48 64 128 256; do
    run install -d -m 0755 "${ICON_DIR}/${size}x${size}/apps"
    run cp "$LOGO_SRC" "${ICON_DIR}/${size}x${size}/apps/core-os.${logo_ext}"
  done
else
  warn "no se encontró branding/logo/core-os.{png,svg}"
fi

# --- /etc/os-release --------------------------------------------------------
log "Escribiendo identidad del sistema (/etc/os-release)..."
cat > /etc/os-release <<EOF
PRETTY_NAME="${CORE_OS_NAME} ${CORE_OS_RELEASE}"
NAME="${CORE_OS_NAME}"
VERSION_ID="${CORE_OS_RELEASE}"
VERSION="${CORE_OS_RELEASE} (${UBUNTU_CODENAME})"
VERSION_CODENAME=${UBUNTU_CODENAME}
ID=core-os
ID_LIKE=ubuntu debian
HOME_URL="https://github.com/sebrudo123/core-os"
SUPPORT_URL="https://github.com/sebrudo123/core-os/issues"
UBUNTU_CODENAME=${UBUNTU_CODENAME}
EOF
run cp /etc/os-release /usr/lib/os-release

cat > /etc/lsb-release <<EOF
DISTRIB_ID=${CORE_OS_NAME}
DISTRIB_RELEASE=${CORE_OS_RELEASE}
DISTRIB_CODENAME=${UBUNTU_CODENAME}
DISTRIB_DESCRIPTION="${CORE_OS_NAME} ${CORE_OS_RELEASE}"
EOF

# --- Mensajes de login ------------------------------------------------------
cat > /etc/issue <<EOF
${CORE_OS_NAME} ${CORE_OS_RELEASE} \\n \\l
EOF

cat > /etc/issue.net <<EOF
${CORE_OS_NAME} ${CORE_OS_RELEASE}
EOF

log "30-branding.sh completado"
