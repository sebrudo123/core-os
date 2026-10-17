#!/usr/bin/env bash
# shellcheck disable=SC2034
# ===========================================================================
#  Core OS — perfil de archiso
#
#  Base: Arch Linux (kernel `linux` + escritorio GNOME).
#  La ISO se compone desde cero con `pacstrap` + `mkarchiso`: aquí no hay
#  ninguna capa de otra distribución, ni preseed, ni scripts de terceros.
#
#  Compilación (dentro de un contenedor Arch):
#     customization/arch/build-iso.sh
#
#  Ver customization/arch/README.md
# ===========================================================================

iso_name="core-os"
iso_label="CORE_OS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Core OS <https://github.com/sebrudo123/core-os>"
iso_application="Core OS — Live / Install (Arch Linux)"
iso_version="${CORE_OS_VERSION:-1.0.0}"
install_dir="coreos"
arch="x86_64"
pacman_conf="pacman.conf"

# La raíz del medio en vivo se comprime con xz (mejor ratio que zstd: mantiene
# la ISO por debajo del límite de 2 GB por asset de GitHub Releases).
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# BIOS (syslinux, "isohybrid") + UEFI (GRUB con el tema de Core OS).
bootmodes=('bios.syslinux' 'uefi.grub')

# Consola serie: imprescindible para diagnosticar el arranque en CI (la ISO se
# prueba en QEMU y el log serie es lo único legible cuando no hay pantalla).
kernel_params_x86_64="console=tty0 console=ttyS0,115200"

# Permisos aplicados a la raíz del medio tras copiar `airootfs/`.
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/core-os-setup"]="0:0:755"
)
