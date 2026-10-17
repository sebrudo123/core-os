#!/usr/bin/env bash
# ===========================================================================
#  check.sh — Comprobaciones del sistema Core OS antes de construir.
#
#  Se ejecuta en el job de validación de CI y también se puede lanzar a mano:
#
#      ./customization/arch/check.sh
#
#  Verifica tres cosas:
#    1. que no queden mecanismos de otra distribución en el código de Core OS,
#    2. que los paquetes imprescindibles estén en la lista,
#    3. que existan los archivos que el perfil de archiso necesita.
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

fail() { printf '\033[1;31mFALLO:\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }

# --- 1. Sin mecanismos de otra distribución --------------------------------
# Solo se revisa CÓDIGO (scripts, unidades, configuración), nunca la
# documentación. Este propio archivo queda fuera: contiene los patrones.
PATTERNS='casper|ubiquity|gdm3|lsb-release|/etc/default/ubuntu|apt-get|apt install|cloud-init'
LEFTOVERS="$(grep -rniE "$PATTERNS" \
    customization/arch customization/archiso customization/systemd \
    customization/setup customization/branding/tools 2>/dev/null \
    | grep -vE '\.(md|txt):' | grep -v 'arch/check\.sh:' || true)"
if [ -n "$LEFTOVERS" ]; then
    printf '%s\n' "$LEFTOVERS"
    fail "quedan restos de otra distribución en el código"
fi
ok "sin restos de la distribución base anterior"

# --- 2. Paquetes imprescindibles -------------------------------------------
PACKAGES="customization/archiso/packages.x86_64"
[ -s "$PACKAGES" ] || fail "falta $PACKAGES"

for pkg in base linux linux-firmware mkinitcpio mkinitcpio-archiso arch-install-scripts \
           grub syslinux efibootmgr os-prober gptfdisk parted dosfstools e2fsprogs \
           gnome-shell gnome-session gdm networkmanager firefox flatpak \
           nodejs python python-gobject gtk3 webkit2gtk-4.1; do
    grep -qx "$pkg" "$PACKAGES" || fail "el paquete '$pkg' no está en $PACKAGES"
done
ok "lista de paquetes completa"

# --- 3. Archivos del perfil ------------------------------------------------
for file in customization/archiso/profiledef.sh \
            customization/archiso/grub/grub.cfg \
            customization/archiso/syslinux/syslinux.cfg \
            customization/archiso/syslinux/archiso_head.cfg \
            customization/archiso/airootfs/root/customize_airootfs.sh \
            customization/archiso/airootfs/etc/gdm/custom.conf \
            customization/archiso/airootfs/etc/dconf/db/local.d/00-core-os \
            customization/setup/core-os-setup.py \
            customization/setup/ui/index.html \
            customization/setup/ui/style.css \
            customization/setup/ui/app.js \
            customization/setup/ui/logo.png \
            customization/systemd/core-os-setupd.service \
            customization/systemd/core-os-web-demo.service \
            customization/systemd/core-os-diagnostico.service \
            customization/systemd/core-os-live-session.service \
            customization/branding/grub/theme.txt \
            customization/branding/grub/background.png \
            customization/branding/logo/core-os.png \
            customization/branding/wallpapers/core-os-default.svg; do
    [ -s "$file" ] || fail "falta o está vacío: $file"
done
ok "archivos del perfil presentes"

# --- 4. Sintaxis de los scripts --------------------------------------------
for script in customization/arch/scripts/*.sh customization/arch/scripts/lib/*.sh \
              customization/arch/build-iso.sh customization/arch/stage.sh \
              customization/archiso/airootfs/root/customize_airootfs.sh \
              customization/archiso/profiledef.sh; do
    bash -n "$script" || fail "error de sintaxis en $script"
done
ok "sintaxis de todos los scripts correcta"

# El asistente es Python: un error de sintaxis ahí dejaría el medio en vivo sin
# instalador, así que se comprueba antes de construir la ISO.
python3 -c '
import sys
ruta = sys.argv[1]
with open(ruta) as fh:
    compile(fh.read(), ruta, "exec")
' customization/setup/core-os-setup.py \
    || fail "error de sintaxis en customization/setup/core-os-setup.py"
ok "sintaxis del asistente correcta"

printf '\n\033[1;32mTodo correcto.\033[0m\n'
