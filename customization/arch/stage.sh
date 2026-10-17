#!/usr/bin/env bash
# ===========================================================================
#  stage.sh — Prepara el perfil de archiso con el material de Core OS.
#
#  mkarchiso solo copia lo que haya dentro del perfil, así que antes de
#  construir hay que "montar" ahí:
#
#    · el panel web        (web-demo/)                 -> /opt/core-os/web-demo
#    · el asistente        (customization/setup/)      -> /opt/core-os/setup
#    · la marca            (customization/branding/)   -> /opt/core-os/branding
#    · los scripts         (customization/arch/scripts)-> /opt/core-os/scripts
#    · las unidades        (customization/systemd/)    -> /opt/core-os/systemd
#    · el tema de arranque -> archiso/grub/themes/... y archiso/syslinux/
#
#  El script es idempotente: se puede repetir tantas veces como haga falta.
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${REPO_ROOT}/customization/archiso"
OVERLAY="${PROFILE}/airootfs/opt/core-os"
BRANDING="${REPO_ROOT}/customization/branding"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  aviso\033[0m %s\n' "$*" >&2; }

[ -d "$PROFILE" ] || { echo "ERROR: falta el perfil ${PROFILE}" >&2; exit 1; }

log "Limpiando el material anterior…"
rm -rf "$OVERLAY"
rm -rf "${PROFILE}/grub/themes"
rm -f "${PROFILE}/syslinux/splash.png"
install -d -m 0755 "$OVERLAY"

# --- Scripts de personalización -------------------------------------------
log "Copiando los scripts de personalización…"
cp -a "${REPO_ROOT}/customization/arch/scripts" "${OVERLAY}/scripts"

# La versión construida viaja junto a los scripts para que la personalización
# (dentro del chroot, donde no llega el entorno del build) sepa cuál es.
printf '%s\n' "${CORE_OS_VERSION:-1.0.0}" > "${OVERLAY}/scripts/VERSION"

# --- Asistente de instalación ---------------------------------------------
log "Copiando el asistente de instalación…"
install -d -m 0755 "${OVERLAY}/setup"
cp -a "${REPO_ROOT}/customization/setup/." "${OVERLAY}/setup/"

# --- Marca (logotipos, fondos, tema de GRUB) ------------------------------
log "Copiando los recursos gráficos…"
cp -a "$BRANDING" "${OVERLAY}/branding"

# --- Unidades de systemd --------------------------------------------------
log "Copiando las unidades de systemd…"
install -d -m 0755 "${OVERLAY}/systemd"
cp -a "${REPO_ROOT}/customization/systemd/." "${OVERLAY}/systemd/"

# --- Panel web (sin node_modules: se instalan durante el build) -----------
log "Copiando el panel web…"
install -d -m 0755 "${OVERLAY}/web-demo"
tar -C "${REPO_ROOT}/web-demo" \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='data/runtime' \
    --exclude='*.log' \
    -cf - . | tar -C "${OVERLAY}/web-demo" -xf -

# --- Tema del menú de arranque de la ISO ----------------------------------
# mkarchiso copia al ISO los ficheros que NO son .cfg que estén en grub/.
log "Preparando el tema de GRUB y la pantalla de syslinux…"
install -d -m 0755 "${PROFILE}/grub/themes/core-os"
install -m 0644 "${BRANDING}/grub/theme.txt" "${PROFILE}/grub/themes/core-os/theme.txt"
install -m 0644 "${BRANDING}/grub/background.png" "${PROFILE}/grub/themes/core-os/background.png"
if [ -f "${BRANDING}/grub/logo.png" ]; then
    install -m 0644 "${BRANDING}/grub/logo.png" "${PROFILE}/grub/themes/core-os/logo.png"
fi
if [ -f "${BRANDING}/grub/splash-syslinux.png" ]; then
    install -m 0644 "${BRANDING}/grub/splash-syslinux.png" "${PROFILE}/syslinux/splash.png"
else
    install -m 0644 "${BRANDING}/grub/background.png" "${PROFILE}/syslinux/splash.png"
fi

# La fuente del menú: `${GRUB_FONT}` viaja dentro de la ISO porque el binario
# de GRUB que genera archiso no lleva ninguna incrustada y el tema la necesita.
GRUB_FONT="${GRUB_FONT:-/usr/share/grub/unicode.pf2}"
install -d -m 0755 "${PROFILE}/grub/fonts"
if [ -f "$GRUB_FONT" ]; then
    install -m 0644 "$GRUB_FONT" "${PROFILE}/grub/fonts/unicode.pf2"
    log "Fuente del menú copiada desde ${GRUB_FONT}"
else
    warn "no se encontró ${GRUB_FONT}: el menú se mostrará sin el tema"
fi

log "Listo. Material preparado en ${OVERLAY}"
