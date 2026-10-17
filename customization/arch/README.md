# ===========================================================================
#  Core OS — construcción de la ISO (perfil de archiso)
# ===========================================================================

Aquí vive **todo** lo que convierte Arch Linux en Core OS. Está pensado para
leerse en orden: cada paso hace una cosa y está en un archivo aparte.

## Contenido

```
customization/
├── archiso/                  Perfil de archiso (lo que consume mkarchiso)
│   ├── profiledef.sh         Nombre, etiqueta, modos de arranque, compresión
│   ├── packages.x86_64       Paquetes oficiales de Arch que forman Core OS
│   ├── pacman.conf           Repositorios usados durante la construcción
│   ├── grub/                 Menú de arranque UEFI (más el tema de Core OS)
│   ├── syslinux/             Menú de arranque BIOS
│   └── airootfs/             Archivos que se copian sobre el sistema
│       ├── etc/              identidad, GDM, dconf (ajustes del escritorio)
│       └── root/customize_airootfs.sh   Encadena los scripts de arch/scripts
├── arch/                     Lógica de personalización de Core OS
│   ├── build-iso.sh          Construye la ISO (requiere archiso)
│   ├── stage.sh              Prepara el perfil con el material de Core OS
│   └── scripts/NN-*.sh       Pasos del build (se ejecutan dentro del chroot)
├── branding/                 Logotipos, fondos y tema de arranque
├── setup/                    Asistente de instalación (interfaz + backend)
└── systemd/                  Unidades de los servicios de Core OS
```

## Construir la ISO

En un equipo Arch Linux:

```bash
sudo pacman -S archiso libisoburn squashfs-tools dosfstools mtools grub syslinux
sudo CORE_OS_VERSION=1.0.0 ./customization/arch/build-iso.sh
```

En cualquier otro sistema (por ejemplo Ubuntu o macOS), dentro de un contenedor:

```bash
docker run --rm --privileged -v "$PWD":/work -w /work \
  -e CORE_OS_VERSION=1.0.0 archlinux:latest bash -c '
    pacman-key --init && pacman-key --populate archlinux &&
    pacman -Syu --noconfirm --needed archiso libisoburn squashfs-tools \
      dosfstools mtools grub syslinux &&
    ./customization/arch/build-iso.sh'
```

La ISO aparece en `customization/out/core-os-<versión>-x86_64.iso`.

> El proceso descarga ~4 GB de paquetes y necesita unos 15 GB libres. En los
> runners de GitHub se lanza desde `build-iso.yml` con el volumen grande
> montado en `/mnt`.

## Probar la ISO sin grabarla

```bash
qemu-system-x86_64 -m 4G -enable-kvm -vga std \
  -drive file=customization/out/core-os-1.0.0-x86_64.iso,media=cdrom,readonly=on \
  -boot order=d
```

También se puede probar desde el navegador con el flujo
`.github/workflows/live-preview.yml`.

## Añadir o cambiar cosas

- **Paquetes** → `archiso/packages.x86_64` (solo repositorios oficiales).
- **Ajustes del escritorio (GNOME)** → `archiso/airootfs/etc/dconf/db/local.d/`.
- **Aspecto del panel/escritorio/tema de arranque** → `branding/`.
- **Un paso nuevo del build** → crea `arch/scripts/NN-nombre.sh`; se ejecuta
  solo, en orden numérico.
- **Asistente de instalación** → `setup/`.

## Por qué así

- **`archiso` en vez de rehacerlo a mano**: es la herramienta oficial de Arch,
  mantenida, y genera el arranque BIOS/UEFI, el `squashfs` y el initramfs con
  `mkinitcpio-archiso` sin que tengamos que mantener nada de eso.
- **`customize_airootfs.sh`**: `mkarchiso` lo marca como obsoleto, pero sigue
  soportado y es el mecanismo que usan todas las distribuciones derivadas. Nos
  permite ejecutar nuestros scripts dentro del chroot en orden.
- **Sin AUR**: la ISO debe poder construirse sin ayudantes externos. Por eso el
  aspecto Windows 11 usa `dash-to-panel` + `arc-menu`, que están en los
  repositorios oficiales.
- **El kernel vive en la ISO**: `mkarchiso` borra `/boot` de la raíz en vivo,
  así que el instalador copia el kernel desde el propio medio antes de generar
  el initramfs del sistema instalado.
