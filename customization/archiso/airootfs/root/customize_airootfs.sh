#!/usr/bin/env bash
# ===========================================================================
#  Core OS — personalización de la raíz del medio en vivo.
#
#  archiso copia `airootfs/` sobre el sistema recién creado con pacstrap y
#  después ejecuta ESTE script dentro del chroot (como root). Aquí solo se
#  encadenan los scripts numerados de `customization/arch/scripts/`, que se
#  copiaron a /opt/core-os/scripts/ antes de construir. Así el build queda
#  ordenado y cada paso es legible por separado.
#
#  Este mecanismo (`customize_airootfs.sh`) está marcado como "deprecated" en
#  archiso, pero sigue soportado y es el que usan todas las distribuciones
#  derivadas de Arch.
# ===========================================================================
set -euo pipefail

echo "==> Core OS: personalizando el medio en vivo"

if [ ! -d /opt/core-os/scripts ]; then
    echo "ERROR: falta /opt/core-os/scripts (¿se olvidó 'customization/arch/stage.sh'?)" >&2
    exit 1
fi

for script in /opt/core-os/scripts/[0-9][0-9]-*.sh; do
    [ -e "$script" ] || continue
    echo
    echo "==============================================================="
    echo "== Core OS: $(basename "$script")"
    echo "==============================================================="
    bash "$script"
done

echo
echo "==> Core OS: limpieza del material de construcción"
rm -rf /opt/core-os
rm -rf /var/cache/pacman/pkg/* || true

echo "==> Core OS: medio en vivo listo"
