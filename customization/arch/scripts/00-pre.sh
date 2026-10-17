#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  00-pre.sh — ajustes base del sistema Core OS: idioma, teclado, zona horaria,
#  pacman y estructura de directorios propia.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

# --- Locales ---------------------------------------------------------------
log "Generando locales (es_ES.UTF-8 y en_US.UTF-8)…"
for loc in "es_ES.UTF-8 UTF-8" "en_US.UTF-8 UTF-8"; do
    sed -i "s|^#\s*${loc}|${loc}|" /etc/locale.gen
    grep -qx "${loc}" /etc/locale.gen || printf '%s\n' "${loc}" >> /etc/locale.gen
done
run locale-gen
printf 'LANG=es_ES.UTF-8\n' > /etc/locale.conf

# --- Teclado ---------------------------------------------------------------
log "Configurando el teclado en español…"
cat > /etc/vconsole.conf <<'EOF'
KEYMAP=es
FONT=lat9w-16
EOF
run install -d -m 0755 /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/00-core-os-keyboard.conf <<'EOF'
# Core OS — distribución de teclado por defecto (el instalador la ajusta).
Section "InputClass"
    Identifier "core-os-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "es"
    Option "XkbVariant" ""
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
EOF

# --- Zona horaria ----------------------------------------------------------
log "Ajustando la zona horaria (Europe/Madrid)…"
run ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
run hwclock --systohc --utc || warn "no se pudo sincronizar el reloj del hardware"

# --- pacman ----------------------------------------------------------------
log "Ajustando /etc/pacman.conf…"
sed -i 's|^#\s*Color$|Color|' /etc/pacman.conf
sed -i 's|^#\s*ParallelDownloads\s*=.*|ParallelDownloads = 5|' /etc/pacman.conf
grep -q '^Color' /etc/pacman.conf || sed -i '/^\[options\]/a Color' /etc/pacman.conf
grep -q '^ILoveCandy' /etc/pacman.conf || sed -i '/^Color/a ILoveCandy' /etc/pacman.conf

# La lista de servidores de Arch viene comentada; se activan los HTTPS para
# que el sistema en vivo (y el instalado) puedan usar pacman.
log "Activando servidores HTTPS en /etc/pacman.d/mirrorlist…"
sed -i 's|^#\(Server = https:\)|\1|' /etc/pacman.d/mirrorlist || true

# --- Estructura de Core OS -------------------------------------------------
run install -d -m 0755 /usr/lib/core-os /etc/core-os /var/log/core-os

# Fichero con la identidad, usado por el panel web y el asistente.
cat > /etc/core-os/release <<EOF
CORE_OS_NAME="${CORE_OS_NAME}"
CORE_OS_RELEASE="${CORE_OS_RELEASE}"
CORE_OS_CODENAME="core"
CORE_OS_BASE="${CORE_OS_BASE}"
CORE_OS_REPOSITORY="${CORE_OS_REPO_URL}"
EOF

ok "00-pre.sh completado"
