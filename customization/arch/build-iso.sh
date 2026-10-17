#!/usr/bin/env bash
# ===========================================================================
#  build-iso.sh — Construye la ISO de Core OS con archiso.
#
#  Requiere un sistema Arch Linux con:  pacman -S archiso
#
#  En un equipo que no sea Arch, ejecútalo dentro de un contenedor:
#
#    docker run --rm --privileged -v "$PWD":/work -w /work \
#      -e CORE_OS_VERSION=1.0.0 archlinux:latest bash -c '
#        pacman-key --init && pacman-key --populate archlinux &&
#        pacman -Syu --noconfirm --needed archiso dosfstools mtools grub syslinux &&
#        ./customization/arch/build-iso.sh'
#
#  Ver .github/workflows/build-iso.yml para el uso exacto en CI.
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${REPO_ROOT}/customization/archiso"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/customization/out}"
WORK_DIR="${WORK_DIR:-${REPO_ROOT}/customization/work}"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  aviso\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "falta '$1'${2:+ ($2)}"; }

require mkarchiso "pacman -S archiso"
require pacstrap   "pacman -S arch-install-scripts"
require mksquashfs "pacman -S squashfs-tools"
require xorriso    "pacman -S libisoburn"
require mkfs.fat   "pacman -S dosfstools"
require mcopy      "pacman -S mtools"
require grub-mkstandalone "pacman -S grub"

if [ "$(id -u)" -ne 0 ]; then
    die "archiso necesita privilegios de root (usa sudo o un contenedor)"
fi

export CORE_OS_VERSION="${CORE_OS_VERSION:-1.0.0}"
log "Construyendo Core OS ${CORE_OS_VERSION}"

# --- 1. Preparar el perfil -------------------------------------------------
bash "${REPO_ROOT}/customization/arch/stage.sh"

# --- 2. Construir ----------------------------------------------------------
log "Directorio de trabajo: ${WORK_DIR}"
log "Salida:                ${OUT_DIR}"

build_once() {
    rm -rf "$WORK_DIR"
    install -d -m 0755 "$WORK_DIR" "$OUT_DIR"
    # mkarchiso lee CORE_OS_VERSION y CORE_OS_SQUASHFS del entorno al procesar
    # profiledef.sh.
    mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE"
}

# Primero con xz (mejor compresión). Si la compresión fallara, se reintenta con
# zstd, que es más rápido y no pasa por el mismo camino de código: así la ISO se
# genera igualmente aunque el compresor xz del sistema tenga algún problema.
if ! build_once; then
    warn "la construcción con xz falló: se vuelve a intentar con zstd"
    rm -f "${OUT_DIR}"/*.iso
    export CORE_OS_SQUASHFS=zstd
    build_once || die "la construcción de la ISO falló también con zstd"
fi

# --- 3. Resultado ----------------------------------------------------------
iso="$(ls -1 "${OUT_DIR}"/*.iso | head -1)"
[ -n "$iso" ] || die "mkarchiso no generó ninguna ISO"
log "ISO generada: ${iso} ($(du -h "$iso" | cut -f1))"

cd "$OUT_DIR"
sha256sum "$(basename "$iso")" > SHA256SUMS
log "Suma de verificación: $(cat SHA256SUMS)"
