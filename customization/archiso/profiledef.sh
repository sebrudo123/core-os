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

# Compresor de la raíz del medio en vivo.
#
# Por defecto se usa xz: comprime mejor que zstd y ayuda a mantener la ISO por
# debajo del límite de 2 GB por archivo de GitHub Releases.
#
# Con CORE_OS_SQUASHFS=zstd se cambia a zstd (bastante más rápido). El script de
# construcción lo reintenta así automáticamente si xz diera algún problema.
#
# No se usa el filtro `-Xbcj x86`: con bloques de 1 MiB, squashfs-tools 4.7
# aborta la compresión («xz uncompress failed with error code 9») al comprobar
# el resultado, y el ahorro que aportaba era de apenas un 2 %.
airootfs_image_type="squashfs"
case "${CORE_OS_SQUASHFS:-xz}" in
    zstd) airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M') ;;
    *)    airootfs_image_tool_options=('-comp' 'xz' '-b' '1M') ;;
esac
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')

# BIOS (syslinux, "isohybrid") + UEFI (GRUB con el tema de Core OS).
bootmodes=('bios.syslinux' 'uefi.grub')

# Consola serie: imprescindible para diagnosticar el arranque en CI (la ISO se
# prueba en QEMU y el log serie es lo único legible cuando no hay pantalla).
kernel_params_x86_64="console=tty0 console=ttyS0,115200"

# Permisos aplicados a la raíz del medio tras copiar `airootfs/`.
#
# OJO: aquí solo se pueden indicar rutas que EXISTAN en `airootfs/`; mkarchiso
# comprueba la ruta antes de que se instalen los paquetes (los archivos de los
# paquetes ya conservan sus permisos). Con una ruta inexistente, mkarchiso
# aborta con «Outside of valid path».
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
