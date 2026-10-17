# Arquitectura de Core OS

Core OS es un sistema operativo propio construido **desde Arch Linux**. No es
una capa encima de otra distribución: la ISO se compone con `pacstrap` +
`archiso`, así que todo lo que hay dentro está elegido y configurado aquí.

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Repositorio (GitHub: sebrudo123/core-os)                                │
│                                                                          │
│   web-demo/               panel de administración (Node + Express)       │
│   customization/archiso/  perfil de archiso (paquetes, arranque, dconf)  │
│   customization/arch/     scripts de personalización (se ejecutan en el  │
│                           chroot durante la construcción)                │
│   customization/setup/    asistente de instalación (interfaz + backend)  │
│   customization/branding/ logotipos, fondos y tema de arranque            │
│                                                                          │
│   .github/workflows/      CI: validar → construir ISO → publicar Release │
└──────────────────────────────────────────────────────────────────────────┘
```

## 1. Cómo se construye la ISO

1. **`customization/arch/stage.sh`** copia al perfil de archiso todo lo que
   necesita el medio en vivo (panel, asistente, marca, scripts y unidades de
   systemd) dentro de `archiso/airootfs/opt/core-os/`.
2. **`mkarchiso`** (el constructor oficial de Arch) hace el trabajo:
   - instala con `pacstrap` los paquetes de `packages.x86_64` (base, kernel,
     GNOME, Firefox, Node…),
   - copia `archiso/airootfs/` encima del sistema recién instalado,
   - ejecuta `airootfs/root/customize_airootfs.sh` dentro del chroot, que
     encadena nuestros scripts `customization/arch/scripts/NN-*.sh`,
   - borra `/boot` (el kernel va a la ISO), limpia la caché de pacman y genera
     el `squashfs` comprimido con xz,
   - monta el arranque: **syslinux** para BIOS y **GRUB** (con nuestro tema)
     para UEFI.
3. El resultado es `customization/out/core-os-<versión>-x86_64.iso`.

Los scripts se ejecutan **en orden numérico**, y cada uno hace una sola cosa:

| Script | Responsabilidad |
|---|---|
| `00-pre.sh` | idioma, teclado, zona horaria, `pacman.conf`, estructura de `/etc/core-os` |
| `10-desktop.sh` | GNOME con aspecto Windows 11: `dash-to-panel`, `arc-menu`, iconos, tema oscuro, `dconf update` |
| `20-branding.sh` | `/etc/os-release`, nombre del equipo, logotipos, fondos, tema de GRUB |
| `30-live-user.sh` | usuario `core` (UID 1000), sudo sin contraseña e inicio de sesión automático |
| `40-services.sh` | GDM, NetworkManager, Bluetooth, CUPS, PipeWire y servicios de Core OS |
| `45-web-demo.sh` | panel de administración como servicio en el puerto 8080 |
| `50-installer.sh` | asistente de instalación (interfaz WebKit + servicio root) |
| `60-flatpak.sh` | repositorio Flathub |
| `99-cleanup.sh` | cachés, registros y `/etc/machine-id` |

## 2. El medio en vivo

- Arranca **directamente en el escritorio**: el usuario `core` entra solo
  (autologin de GDM). No hay pantalla de inicio de sesión ni consola de root.
- El usuario `core` tiene `sudo` sin contraseña (es un medio efímero, pensado
  para probar e instalar).
- La raíz es un `squashfs` de solo lectura con una capa de escritura en RAM:
  nada de lo que se haga en la sesión en vivo toca el disco.
- El instalador se abre automáticamente a los pocos segundos.

## 3. El instalador (estilo Windows 11)

- **Interfaz** (`customization/setup/ui/`): asistente HTML/CSS/JS de cuatro
  pasos (idioma → disco → cuenta → instalación) mostrado a pantalla completa
  con WebKit2GTK.
- **Backend** (`customization/setup/core-os-setup.py`): servicio root que
  expone una API en `127.0.0.1:8765` y hace la instalación **real**:
  `sgdisk` para particionar, `mkfs`, `rsync` del sistema, `genfstab`,
  `mkinitcpio -P`, `grub-install` + `grub-mkconfig` y creación de la cuenta.
- Solo se muestra en el medio en vivo (`/run/archiso`); el instalador borra
  además todos los restos del medio en vivo (usuario `core`, autologin,
  servicios del ISO, ganchos de pacman) del sistema instalado.

## 4. El panel de administración

`web-demo/` es una aplicación Node/Express sin base de datos:

- En la **web** (Render) se ejecuta con `DEMO_MODE=true`.
- Dentro de **Core OS** se instala como servicio `core-os-web-demo.service`
  con `DEMO_MODE=false`, de modo que muestra las métricas reales del equipo en
  `http://localhost:8080`.

Ambos son el mismo código: lo que se ve en la web es lo que se ve instalado.

## 5. Integración continua

| Flujo | Qué hace |
|---|---|
| `ci.yml` | `shellcheck` + sintaxis de bash, comprobación del asistente y prueba de humo del panel |
| `build-iso.yml` | valida, construye la ISO dentro de un contenedor `archlinux:latest` y, en los tags `v*`, publica la Release (ISO o partes de <2 GB + sumas SHA-256) |
| `live-preview.yml` | arranca la ISO en QEMU/KVM, la publica por noVNC con un túnel y guarda capturas del escritorio |
| `deploy-web.yml` | comprueba el panel y lanza el despliegue en Render |

## 6. Prueba del sistema sin instalarlo

`live-preview.yml` arranca la **ISO real** en una máquina virtual y la expone en
el navegador: se puede usar el ratón, el teclado y ver el escritorio de verdad.
En cada ejecución publica:

- `<túnel>/vnc.html?autoconnect=1` — escritorio interactivo,
- `<túnel>/shots/latest.png` — última captura de pantalla,
- `<túnel>/shots/serial.log` — registro de la consola serie (diagnóstico).
