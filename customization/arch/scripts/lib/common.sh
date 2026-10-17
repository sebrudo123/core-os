#!/usr/bin/env bash
# shellcheck disable=SC2034  # las variables se usan desde los demás scripts
# ===========================================================================
#  Core OS — funciones comunes de los scripts de personalización.
#
#  Estos scripts se ejecutan DENTRO del chroot del medio en vivo (como root),
#  encadenados por `archiso/airootfs/root/customize_airootfs.sh`.
# ===========================================================================

# Valores por defecto (los puede sobrescribir el entorno del build).
CORE_OS_NAME="${CORE_OS_NAME:-Core OS}"
# La versión que se muestra dentro del sistema (asistente, /etc/core-os-release).
# `stage.sh` deja la etiqueta publicada en el perfil; así el medio en vivo
# muestra la misma versión que la ISO y no el 1.0.0 de relleno.
if [ -z "${CORE_OS_RELEASE:-}" ] && [ -r /opt/core-os/scripts/VERSION ]; then
    CORE_OS_RELEASE="$(tr -d '[:space:]' < /opt/core-os/scripts/VERSION)"
fi
CORE_OS_RELEASE="${CORE_OS_RELEASE#v}"
CORE_OS_RELEASE="${CORE_OS_RELEASE:-1.0.0}"
CORE_OS_BASE="${CORE_OS_BASE:-Arch Linux}"
CORE_OS_LIVE_USER="${CORE_OS_LIVE_USER:-core}"
CORE_OS_LIVE_PASS="${CORE_OS_LIVE_PASS:-core}"
CORE_OS_LIVE_HOST="${CORE_OS_LIVE_HOST:-core-os}"
CORE_OS_WEB_DEMO_PORT="${CORE_OS_WEB_DEMO_PORT:-8080}"
CORE_OS_WALLPAPER_DIR="${CORE_OS_WALLPAPER_DIR:-/usr/share/backgrounds/core-os}"
CORE_OS_PAYLOAD="${CORE_OS_PAYLOAD:-/opt/core-os}"
CORE_OS_REPO_URL="https://github.com/sebrudo123/core-os"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  aviso\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m  error\033[0m %s\n' "$*" >&2; exit 1; }

run() { printf '    $ %s\n' "$*"; "$@"; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "este script debe ejecutarse como root"
}

is_live_medium() {
    # archiso crea /run/archiso en el medio en vivo (y todos los sistemas
    # basados en archiso lo respetan).
    [ -d /run/archiso ]
}

# Ruta del payload copiado al chroot por `customization/arch/stage.sh`.
payload_path() { printf '%s/%s\n' "$CORE_OS_PAYLOAD" "$1"; }
