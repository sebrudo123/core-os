#!/usr/bin/env bash
# shellcheck shell=bash
# ---------------------------------------------------------------------------
# common.sh — helpers compartidos por los scripts de personalización de Core OS.
# Se carga con:  # shellcheck source=lib/common.sh
#                source "$(dirname "$0")/lib/common.sh"
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOMIZATION_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export CORE_OS_NAME="${CORE_OS_NAME:-Core OS}"
export CORE_OS_RELEASE="${CORE_OS_RELEASE:-1.0.0}"
export CORE_OS_DRY_RUN="${CORE_OS_DRY_RUN:-0}"
export UBUNTU_RELEASE="${UBUNTU_RELEASE:-24.04}"
export UBUNTU_CODENAME="${UBUNTU_CODENAME:-noble}"
export CUSTOMIZATION_DIR

log()  { printf '\033[1;34m[core-os]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[core-os]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[core-os] aviso:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[core-os] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [ "$(id -u)" -eq 0 ] || die "este script debe ejecutarse como root (usa sudo)"
}

# Ejecuta un comando salvo en modo dry-run.
run() {
  if [ "$CORE_OS_DRY_RUN" = "1" ]; then
    log "DRY-RUN: $*"
  else
    "$@"
  fi
}

# Lista un archivo de paquetes ignorando comentarios y líneas vacías.
list_packages() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$file" | tr -d '\r'
}
