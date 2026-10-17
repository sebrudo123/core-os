#!/usr/bin/env bash
# ===========================================================================
#  build-iso.sh — Constructor de la ISO de Core OS (modo headless)
#
#  Toma una ISO oficial de Ubuntu, aplica la personalización de
#  customization/ dentro de un chroot y reempaqueta una nueva ISO arrancable.
#
#  No necesita entorno gráfico: es la alternativa a Cubic para CI/CD.
#
#  Uso:
#    ./build-iso.sh [opciones]
#
#  Opciones:
#    -r, --release <v>        Versión de Core OS (por defecto 1.0.0)
#        --ubuntu-release <v> Release de Ubuntu base (por defecto 24.04)
#        --ubuntu-codename <c> Codename de Ubuntu (por defecto noble)
#        --url <url>          URL de la ISO base (por defecto, auto)
#        --work <dir>         Directorio de trabajo (por defecto ./work)
#        --out <dir>          Directorio de salida (por defecto ./out)
#        --prepare-only       Sólo prepara el árbol y aplica scripts (no repaqueta)
#        --no-download        Usa la ISO cacheada; falla si no existe
#    -k, --keep               Conserva los directorios temporales
#    -n, --dry-run            Valida herramientas y configuración, sin construir
#    -h, --help               Muestra esta ayuda
# ===========================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración por defecto
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOMIZATION_DIR="$SCRIPT_DIR"
REPO_ROOT="$(cd "$CUSTOMIZATION_DIR/.." && pwd)"

CORE_OS_RELEASE="${CORE_OS_RELEASE:-1.0.0}"
UBUNTU_RELEASE="${UBUNTU_RELEASE:-24.04}"
UBUNTU_CODENAME="${UBUNTU_CODENAME:-noble}"
UBUNTU_POINT="${UBUNTU_POINT:-2}"

WORK_DIR="${WORK_DIR:-$CUSTOMIZATION_DIR/work}"
OUT_DIR="${OUT_DIR:-$CUSTOMIZATION_DIR/out}"
CACHE_DIR="${CACHE_DIR:-$CUSTOMIZATION_DIR/cache}"

ISO_URL="${ISO_URL:-}"
ISO_FILE=""            # se calcula tras resolver ISO_URL
OUTPUT_ISO=""

DRY_RUN=0
KEEP=0
PREPARE_ONLY=0
NO_DOWNLOAD=0
VOLID="CORE_OS"

# ---------------------------------------------------------------------------
# Utilidades de log
# ---------------------------------------------------------------------------
c_reset='\033[0m'; c_blue='\033[1;34m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_green='\033[1;32m'
log()  { printf "${c_blue}[build-iso]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_green}[build-iso]${c_reset} %s\n" "$*"; }
warn() { printf "${c_yellow}[build-iso] aviso:${c_reset} %s\n" "$*" >&2; }
die()  { printf "${c_red}[build-iso] ERROR:${c_reset} %s\n" "$*" >&2; exit 1; }

die_usage() { die "$*"; }

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------------------
# Parseo de argumentos
# ---------------------------------------------------------------------------
parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -r|--release)          CORE_OS_RELEASE="$2"; shift 2 ;;
      --ubuntu-release)      UBUNTU_RELEASE="$2"; shift 2 ;;
      --ubuntu-codename)     UBUNTU_CODENAME="$2"; shift 2 ;;
      --url)                 ISO_URL="$2"; shift 2 ;;
      --work)                WORK_DIR="$2"; shift 2 ;;
      --out)                 OUT_DIR="$2"; shift 2 ;;
      --prepare-only)        PREPARE_ONLY=1; shift ;;
      --no-download)         NO_DOWNLOAD=1; shift ;;
      -k|--keep)             KEEP=1; shift ;;
      -n|--dry-run)          DRY_RUN=1; shift ;;
      -h|--help)             usage; exit 0 ;;
      *) die_usage "opción desconocida: $1 (usa --help)" ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Resolución de la URL de la ISO base
# ---------------------------------------------------------------------------
# Descubre la ISO de escritorio más reciente del release indicado, en lugar de
# asumir un point release concreto (que cambia con el tiempo y provoca 404).
resolve_iso_url() {
  local base="https://releases.ubuntu.com/${UBUNTU_RELEASE}/"
  local listing=""

  if command -v wget >/dev/null 2>&1; then
    listing="$(wget -qO- "$base" 2>/dev/null || true)"
  elif command -v curl >/dev/null 2>&1; then
    listing="$(curl -fsSL "$base" 2>/dev/null || true)"
  fi

  local candidate
  candidate="$(printf '%s' "$listing" \
    | grep -oE "ubuntu-${UBUNTU_RELEASE}(\.[0-9]+)?-desktop-amd64\.iso" \
    | sort -u | sort -V | tail -1)"

  if [ -n "$candidate" ]; then
    ISO_URL="${base}${candidate}"
    log "ISO base detectada automáticamente: ${candidate}"
    return 0
  fi

  # Fallback: prueba candidatos de point release conocidos.
  local p name
  for p in 4 3 2 1; do
    name="ubuntu-${UBUNTU_RELEASE}.${p}-desktop-amd64.iso"
    if command -v curl >/dev/null 2>&1 && curl -fsI "${base}${name}" >/dev/null 2>&1; then
      ISO_URL="${base}${name}"
      log "ISO base (fallback) detectada: ${name}"
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Resolución de rutas derivadas
# ---------------------------------------------------------------------------
resolve_paths() {
  if [ -z "$ISO_URL" ]; then
    resolve_iso_url || ISO_URL="https://releases.ubuntu.com/${UBUNTU_RELEASE}/ubuntu-${UBUNTU_RELEASE}.${UBUNTU_POINT}-desktop-amd64.iso"
  fi

  ISO_FILE="$CACHE_DIR/$(basename "$ISO_URL")"
  ISO_TREE="$WORK_DIR/iso"
  EDIT_TREE="$WORK_DIR/edit"
  SQUASHFS_REL="casper/filesystem.squashfs"
  OUTPUT_ISO="$OUT_DIR/core-os-${CORE_OS_RELEASE}-amd64.iso"
}

# ---------------------------------------------------------------------------
# Comprobaciones
# ---------------------------------------------------------------------------
check_dependencies() {
  log "Comprobando herramientas necesarias..."
  local missing=()
  # xorriso: extrae/crea la ISO. unsquashfs/mksquashfs: sistema de archivos.
  for tool in xorriso unsquashfs mksquashfs rsync; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    missing+=("wget|curl")
  fi
  if [ "${#missing[@]}" -gt 0 ]; then
    die "faltan herramientas: ${missing[*]}
Instálalas con:
  sudo apt-get install -y xorriso squashfs-tools rsync wget isolinux syslinux-utils"
  fi
  ok "Todas las herramientas están disponibles"
}

check_root_for_build() {
  if [ "$DRY_RUN" -eq 0 ] && [ "$(id -u)" -ne 0 ]; then
    die "la construcción real debe ejecutarse como root (usa sudo). Para validar usa --dry-run"
  fi
}

validate_customization() {
  log "Validando la personalización..."
  [ -d "$CUSTOMIZATION_DIR/scripts" ] || die "no existe $CUSTOMIZATION_DIR/scripts"
  [ -s "$CUSTOMIZATION_DIR/packages/packages.list" ] || die "packages.list vacío"
  local count
  count=$(find "$CUSTOMIZATION_DIR/scripts" -maxdepth 1 -name '[0-9][0-9]-*.sh' | wc -l | tr -d ' ')
  [ "$count" -gt 0 ] || die "no hay scripts NN-*.sh en scripts/"
  ok "Personalización válida ($count scripts de post-instalación)"
}

# ---------------------------------------------------------------------------
# Descarga de la ISO base
# ---------------------------------------------------------------------------
download_base_iso() {
  if [ -f "$ISO_FILE" ]; then
    local cached_size
    cached_size=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo 0)
    if [ "$cached_size" -gt 500000000 ]; then
      ok "ISO base ya en caché: $ISO_FILE"
      return 0
    fi
    warn "la ISO en caché parece incompleta/corrupta; se descargará de nuevo"
    rm -f "$ISO_FILE"
  fi

  if [ "$NO_DOWNLOAD" -eq 1 ]; then
    die "no hay ISO en caché ($ISO_FILE) y se pasó --no-download"
  fi

  log "Descargando ISO base: $ISO_URL"
  mkdir -p "$CACHE_DIR"
  rm -f "${ISO_FILE}.part"

  local rc=0
  if command -v wget >/dev/null 2>&1; then
    wget -c -O "${ISO_FILE}.part" "$ISO_URL" || rc=$?
  else
    curl -L --fail -C - -o "${ISO_FILE}.part" "$ISO_URL" || rc=$?
  fi

  if [ "$rc" -ne 0 ] || [ ! -s "${ISO_FILE}.part" ]; then
    rm -f "${ISO_FILE}.part"
    die "no se pudo descargar la ISO desde $ISO_URL
  Comprueba la URL con --url o revisa la conexión. (¿Point release retirado?)"
  fi

  # Verifica que sea una ISO real (evita páginas de error HTML).
  local size
  size=$(stat -c%s "${ISO_FILE}.part" 2>/dev/null || echo 0)
  if [ "$size" -lt 500000000 ]; then
    rm -f "${ISO_FILE}.part"
    die "la descarga ($(du -h "${ISO_FILE}.part" 2>/dev/null | cut -f1)) no parece una ISO válida.
  Revisa la URL con --url."
  fi

  mv "${ISO_FILE}.part" "$ISO_FILE"
  ok "ISO base descargada ($(du -h "$ISO_FILE" | cut -f1))"
}

# ---------------------------------------------------------------------------
# Extracción de la ISO y del sistema de archivos
# ---------------------------------------------------------------------------
extract_iso() {
  log "Extrayendo el árbol de la ISO..."
  rm -rf "$ISO_TREE"
  mkdir -p "$ISO_TREE"
  # xorriso extrae sin necesidad de montar (no requiere privilegios).
  xorriso -osirrox on -indev "$ISO_FILE" -extract / "$ISO_TREE" \
    2>&1 | sed 's/^/[xorriso] /' | tail -n 3
  chmod -R u+w "$ISO_TREE"
  [ -f "$ISO_TREE/$SQUASHFS_REL" ] || die "no se encontró $SQUASHFS_REL en la ISO"
  ok "Árbol de la ISO extraído"
}

extract_squashfs() {
  log "Descomprimiendo $SQUASHFS_REL (puede tardar)..."
  rm -rf "$EDIT_TREE"
  mkdir -p "$EDIT_TREE"
  unsquashfs -d "$EDIT_TREE" "$ISO_TREE/$SQUASHFS_REL" \
    -processors "$(nproc)" -no-progress
  ok "Sistema de archivos descomprimido"
}

# ---------------------------------------------------------------------------
# Chroot: montajes y aplicación de la personalización
# ---------------------------------------------------------------------------
MOUNTS=()
setup_chroot_mounts() {
  log "Preparando el chroot..."
  mkdir -p "$EDIT_TREE"/{proc,sys,dev,dev/pts,run}
  for m in proc sys dev dev/pts run; do
    if mount --bind "/$m" "$EDIT_TREE/$m" 2>/dev/null; then
      MOUNTS+=("$EDIT_TREE/$m")
    else
      warn "no se pudo montar /$m (¿contenedor sin privilegios?)"
    fi
  done
  # DNS para que apt funcione dentro del chroot
  if [ -f /etc/resolv.conf ]; then
    cp -f /etc/resolv.conf "$EDIT_TREE/etc/resolv.conf"
  fi
}

teardown_chroot_mounts() {
  local m
  for ((i=${#MOUNTS[@]}-1; i>=0; i--)); do
    m="${MOUNTS[i]}"
    umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
  done
  MOUNTS=()
}

cleanup() {
  teardown_chroot_mounts
  if [ "$KEEP" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    log "Limpiando directorios temporales (usa -k para conservarlos)..."
    rm -rf "$WORK_DIR/iso" "$WORK_DIR/edit" 2>/dev/null || true
  fi
}
trap cleanup EXIT

copy_customization_into_chroot() {
  log "Copiando la personalización dentro del chroot..."
  mkdir -p "$EDIT_TREE/opt/core-os"
  rsync -a --delete \
    --exclude 'out/' --exclude 'work/' --exclude 'cache/' \
    "$CUSTOMIZATION_DIR/" "$EDIT_TREE/opt/core-os/"

  # El Modo Demo Web forma parte del sistema instalado: se copia tal cual para
  # que el panel del SO sea IDÉNTICO a la versión desplegada en la web.
  if [ -d "$REPO_ROOT/web-demo" ]; then
    log "Copiando el Modo Demo Web (web-demo/) dentro del chroot..."
    mkdir -p "$EDIT_TREE/opt/core-os/web-demo"
    rsync -a --delete \
      --exclude 'node_modules/' --exclude '.vercel/' --exclude '*.log' \
      "$REPO_ROOT/web-demo/" "$EDIT_TREE/opt/core-os/web-demo/"
  else
    warn "no se encontró $REPO_ROOT/web-demo; el panel web no se instalará"
  fi
  ok "Personalización copiada a /opt/core-os"
}

run_chroot_scripts() {
  log "Ejecutando los scripts de personalización en el chroot..."
  # Ordena los scripts NN-*.sh y ejecútalos con las variables de entorno.
  local script_list
  script_list="$(cd "$EDIT_TREE/opt/core-os/scripts" && ls -1 [0-9][0-9]-*.sh | sort)"

  chroot "$EDIT_TREE" /usr/bin/env \
    CORE_OS_RELEASE="$CORE_OS_RELEASE" \
    UBUNTU_RELEASE="$UBUNTU_RELEASE" \
    UBUNTU_CODENAME="$UBUNTU_CODENAME" \
    CORE_OS_DRY_RUN=0 \
    DEBIAN_FRONTEND=noninteractive \
    /bin/bash -c "
      set -euo pipefail
      cd /opt/core-os
      for s in $script_list; do
        echo '============================================'
        echo \"[core-os] ejecutando \$s\"
        echo '============================================'
        bash \"scripts/\$s\"
      done
    "
  ok "Personalización aplicada"
}

# ---------------------------------------------------------------------------
# Reempaquetado
# ---------------------------------------------------------------------------
repack_squashfs() {
  log "Recomprimiendo el sistema de archivos (esto tarda varios minutos)..."
  local target="$ISO_TREE/$SQUASHFS_REL"
  rm -f "$target"
  # xz da menor tamaño; gzip es más rápido. Usamos xz por defecto.
  mksquashfs "$EDIT_TREE" "$target" \
    -noappend -comp xz -b 1M -no-progress
  ok "filesystem.squashfs regenerado ($(du -h "$target" | cut -f1))"
}

regenerate_checksums() {
  log "Regenerando md5sum.txt de la ISO..."
  ( cd "$ISO_TREE" && find . -type f -not -name 'md5sum.txt' -print0 \
      | xargs -0 md5sum > md5sum.txt )
  ok "md5sum.txt actualizado"
}

build_iso_image() {
  log "Generando la ISO final..."
  mkdir -p "$OUT_DIR"
  rm -f "$OUTPUT_ISO"

  # Rutas de arranque (varían ligeramente entre releases de Ubuntu).
  local eltorito="boot/grub/i386-pc/eltorito.img"
  local efi_img="EFI/boot/bootx64.efi"
  [ -f "$ISO_TREE/$eltorito" ] || eltorito="boot/grub/i386-pc/eltorito.img"
  if [ ! -f "$ISO_TREE/$efi_img" ] && [ -f "$ISO_TREE/boot/grub/efi.img" ]; then
    efi_img="boot/grub/efi.img"
  fi

  local -a args=(
    -as mkisofs
    -iso-level 3
    -full-iso9660-filenames
    -volid "$VOLID"
    -output "$OUTPUT_ISO"
    -eltorito-boot "$eltorito"
    -no-emul-boot
    -boot-load-size 4
    -boot-info-table
    --grub2-boot-info
    -eltorito-alt-boot
    -e "$efi_img"
    -no-emul-boot
    -isohybrid-gpt-basdat
  )

  # MBR híbrido de GRUB si está presente en el árbol extraído.
  if [ -f "$ISO_TREE/boot/grub/i386-pc/boot_hybrid.img" ]; then
    args+=( --grub2-mbr "$ISO_TREE/boot/grub/i386-pc/boot_hybrid.img" )
  fi

  xorriso "${args[@]}" "$ISO_TREE" 2>&1 | sed 's/^/[xorriso] /' | tail -n 5
  [ -f "$OUTPUT_ISO" ] || die "xorriso no generó la ISO"
  ok "ISO generada: $OUTPUT_ISO ($(du -h "$OUTPUT_ISO" | cut -f1))"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  resolve_paths

  log "Core OS ${CORE_OS_RELEASE} | base Ubuntu ${UBUNTU_RELEASE} (${UBUNTU_CODENAME})"
  log "ISO base: ${ISO_URL}"

  check_dependencies
  validate_customization

  if [ "$DRY_RUN" -eq 1 ]; then
    warn "Modo dry-run: no se construirá la ISO."
    log "Configuración válida. Ejecuta sin --dry-run (como root) para construir."
    exit 0
  fi

  check_root_for_build
  download_base_iso
  extract_iso
  extract_squashfs
  setup_chroot_mounts
  copy_customization_into_chroot
  run_chroot_scripts
  teardown_chroot_mounts
  repack_squashfs
  regenerate_checksums

  if [ "$PREPARE_ONLY" -eq 1 ]; then
    warn "--prepare-only: omitiendo la generación de la ISO."
    ok "Árbol preparado en $ISO_TREE; sistema de archivos en $ISO_TREE/$SQUASHFS_REL"
    exit 0
  fi

  build_iso_image
  ok "¡Core OS construido con éxito!"
  log "Salida: $OUTPUT_ISO"
}

main "$@"
