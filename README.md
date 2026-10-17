# Core OS

Sistema operativo propio basado en **Arch Linux**, con escritorio **GNOME**
preparado para parecerse a **Windows 11**, un **instalador gráfico propio** y un
**panel de administración web** que funciona igual en la web que dentro del
sistema.

Todo el sistema se construye desde cero con `pacstrap` + `archiso`: no hay
ninguna capa intermedia de otra distribución.

<p align="center">
  <img src="customization/branding/logo/core-os.png" width="120" alt="Core OS">
</p>

---

## Probarlo sin instalar nada

| Opción | Cómo | Qué ves |
|---|---|---|
| **Escritorio en vivo (navegador)** | Lanza el flujo **Live Preview** en GitHub Actions y abre el enlace que publica | El escritorio real de Core OS, con ratón y teclado |
| **Panel de administración** | `https://core-os-web-demo.onrender.com` | El panel con métricas reales del servidor |
| **ISO en tu equipo** | Descarga la ISO de [Releases](../../releases) y arráncala en una máquina virtual | El sistema completo, listo para instalar |

En el medio en vivo **entras directamente al escritorio** (no hay pantalla de
inicio de sesión). Si hiciera falta una contraseña:

```
usuario:   core
contraseña: core
```

El asistente de instalación se abre solo a los pocos segundos.

---

## Qué incluye

- **Escritorio tipo Windows 11** — barra de tareas centrada abajo
  (`dash-to-panel`), menú de aplicaciones (`arc-menu`), bandeja del sistema
  (`appindicator`), iconos en el escritorio (`desktop-icons-ng`), tema oscuro y
  fondo de Core OS.
- **Instalador propio** — asistente de cuatro pasos (idioma → disco → cuenta →
  instalación) que particiona, formatea, copia el sistema, genera el initramfs e
  instala GRUB de verdad.
- **Panel de administración** — la misma aplicación que se despliega en la web,
  instalada dentro del sistema como servicio en el puerto `8080` con las
  métricas reales del equipo.
- **Arranque propio** — menú GRUB con el tema de Core OS (UEFI) y syslinux (BIOS).
- **Integración continua** — cada push a `main` construye la ISO; cada tag `v*`
  publica una Release.

---

## Estructura del repositorio

```
customization/
├── archiso/        Perfil de archiso: paquetes, arranque y archivos del sistema
├── arch/           Lógica del build (stage.sh, build-iso.sh, scripts/NN-*.sh)
├── setup/          Asistente de instalación (interfaz web + backend Python)
├── branding/       Logotipos, fondos y tema del menú de arranque
└── systemd/        Unidades de los servicios de Core OS
web-demo/           Panel de administración (Node + Express)
docs/               Arquitectura y despliegue
.github/workflows/  CI, construcción de la ISO, vista previa en vivo y despliegue
```

Detalles en [`docs/architecture.md`](docs/architecture.md) y en
[`customization/arch/README.md`](customization/arch/README.md).

---

## Construir la ISO

En Arch Linux:

```bash
sudo pacman -S archiso libisoburn squashfs-tools dosfstools mtools grub syslinux
sudo CORE_OS_VERSION=1.0.0 ./customization/arch/build-iso.sh
```

Desde cualquier otro sistema, con un contenedor:

```bash
docker run --rm --privileged -v "$PWD":/work -w /work \
  -e CORE_OS_VERSION=1.0.0 archlinux:latest bash -c '
    pacman-key --init && pacman-key --populate archlinux &&
    pacman -Syu --noconfirm --needed archiso libisoburn squashfs-tools \
      dosfstools mtools grub syslinux &&
    ./customization/arch/build-iso.sh'
```

La ISO queda en `customization/out/`. También puedes lanzar el flujo
**Build Core OS ISO** desde la pestaña *Actions*.

### Verificar la descarga

```bash
sha256sum -c SHA256SUMS

# Si la Release trae partes (la ISO supera los 2 GB que admite GitHub):
cat core-os-part-*.part > core-os.iso
sha256sum -c PARTS-SHA256SUMS
```

---

## Panel de administración en la web

`web-demo/` es una aplicación Node/Express sin base de datos:

```bash
cd web-demo
npm install
DEMO_MODE=true npm start        # http://localhost:3000
```

- `DEMO_MODE=true` → métricas simuladas (es lo que se usa en Render).
- `DEMO_MODE=false` → métricas reales del equipo (es lo que usa Core OS
  instalado, en el puerto 8080).

El despliegue en Render está definido en [`render.yaml`](render.yaml) y se
documenta en [`docs/deploy.md`](docs/deploy.md).

---

## Requisitos de Core OS

- Procesador de 64 bits (x86-64).
- 4 GB de RAM (8 GB recomendable) y 25 GB de disco.
- Arranque UEFI o BIOS.

## Licencia

MIT — ver [`LICENSE`](LICENSE). Core OS está construido sobre Arch Linux, cuyos
paquetes mantienen sus propias licencias.
