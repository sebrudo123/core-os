#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 00-pre-chroot.sh — preparación previa dentro del chroot de Core OS.
# Crea la identidad del sistema y verifica el entorno antes de instalar nada.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

log "Preparando Core OS ${CORE_OS_RELEASE} sobre Ubuntu ${UBUNTU_RELEASE} (${UBUNTU_CODENAME})"

# Directorios base del sistema Core OS
run install -d -m 0755 /etc/core-os
run install -d -m 0755 /usr/share/core-os
run install -d -m 0755 /usr/lib/core-os

# Marca de versión consultable por el Modo Demo Web y por scripts
cat > /etc/core-os/release <<EOF
CORE_OS_NAME="${CORE_OS_NAME}"
CORE_OS_RELEASE="${CORE_OS_RELEASE}"
CORE_OS_BASE="ubuntu-${UBUNTU_RELEASE}"
CORE_OS_CODENAME="${UBUNTU_CODENAME}"
EOF
log "Escrito /etc/core-os/release"

# Comprobaciones de entorno
command -v apt-get >/dev/null 2>&1 || die "apt-get no está disponible: ¿estamos dentro de Ubuntu?"
[ -d /etc/apt ] || die "no existe /etc/apt"

# Evita diálogos interactivos durante la construcción
export DEBIAN_FRONTEND=noninteractive
log "DEBIAN_FRONTEND=noninteractive exportado"

log "00-pre-chroot.sh completado"
