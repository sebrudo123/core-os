# customization/ — Personalización de Core OS

Todo lo necesario para transformar una ISO oficial de Ubuntu 24.04 LTS en
**Core OS**. Esta carpeta es **autocontenida**: se puede copiar tal cual a un
proyecto de Cubic o pasarla al `build-iso.sh` para una construcción headless.

## Organización

| Ruta | Contenido |
| --- | --- |
| `packages/packages.list` | Paquetes APT que se instalan en Core OS. |
| `packages/remove.list` | Paquetes que se eliminan de la base de Ubuntu. |
| `scripts/NN-*.sh` | Scripts de post-instalación. Se ejecutan **dentro del chroot**, en orden numérico. |
| `gnome/dconf/core-os.dconf` | Ajustes de GNOME (tema, dock, atajos). Cargables con `dconf load`. |
| `gnome/extensions.list` | Extensiones de GNOME Shell a habilitar. |
| `kde/` | Perfil alternativo para KDE Plasma (opcional). |
| `branding/` | Logo y wallpapers (ver `branding/README.md`). |
| `autoinstall/` | `user-data` + `meta-data` para instalaciones desatendidas (Ubuntu Autoinstall / cloud-init). |
| `cubic/` | Recetas y documentación para el flujo gráfico con Cubic. |
| `iso-tools/` | Helpers de empaquetado (squashfs, xorriso, checksums). |
| `build-iso.sh` | Constructor reproducible de la ISO (modo script, sin GUI). |

## Orden de ejecución de los scripts

```text
00-pre-chroot.sh        # montajes efímeros, variables, sanity checks
10-install-packages.sh  # instala packages.list, purga remove.list
20-gnome-theme.sh       # tema, dconf, extensiones, fuentes
30-branding.sh          # logo, wallpapers, os-release, plymouth
40-core-services.sh     # servicios, primer arranque, usuario admin
99-cleanup.sh           # limpia apt, logs, historial bash (reduce tamaño)
```

## Construir la ISO

```bash
# Sólo validar (sin root, sin descargar nada):
./customization/build-iso.sh --dry-run

# Construcción completa:
sudo ./customization/build-iso.sh --release 1.0.0
```

Resultado: `customization/out/core-os-<release>-amd64.iso`.

## Flujo con Cubic (gráfico)

Si prefieres la GUI, abre Cubic apuntando a la ISO de Ubuntu 24.04 y en la
terminal del chroot ejecuta:

```bash
cp -r /ruta/este-repo/customization /tmp/core-os-customization
cd /tmp/core-os-customization
for s in scripts/*.sh; do bash "$s"; done
```

Consulta `cubic/README.md` y `../docs/cubic-guide.md` para el detalle.
