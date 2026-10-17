# Core OS

> Sistema operativo **propio** basado en **Ubuntu 24.04 LTS (Noble Numbat)** con
> una identidad y un escritorio originales (experiencia tipo **Windows 11**),
> personalización automatizada (Cubic / scripts de chroot), pipeline CI/CD en
> GitHub Actions y un **Modo Demo Web** estilo CasaOS para administradores.

[![Build ISO](https://github.com/sebrudo123/core-os/actions/workflows/build-iso.yml/badge.svg)](../../actions/workflows/build-iso.yml)
[![CI](https://github.com/sebrudo123/core-os/actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

---

## ¿Qué es Core OS?

**Core OS** es una distribución completa con identidad propia (no una simple
copia de Ubuntu): arranca con pantalla de bienvenida, tema de arranque y
escritorio propios, y viene con herramientas de administración ya instaladas
junto a un **panel de administración web** ("Modo Demo") que muestra el estado
del sistema, métricas, historial de compilaciones y una terminal segura.

El proyecto vive en dos grandes bloques:

| Bloque | Carpeta | Propósito |
| --- | --- | --- |
| **Personalización del SO** | [`customization/`](./customization) | Paquetes, tema, branding, scripts de post-instalación, autoinstall y el constructor de la ISO. |
| **Modo Demo Web** | [`web-demo/`](./web-demo) | El **panel de administración** de Core OS. Se instala dentro del SO (servicio systemd) y se despliega también en la web para previsualizarlo. |

---

## Identidad de escritorio (estilo Windows 11)

Core OS no usa el escritorio de Ubuntu tal cual: le da su propia personalidad.

| Elemento | Qué hace Core OS |
| --- | --- |
| **Menú de arranque (GRUB)** | Tema propio con logo, fondo y el nombre **Core OS**. |
| **Splash de arranque (Plymouth)** | Tema propio de Core OS. *(Pendiente: el splash del medio en vivo sale del `initrd`; requiere regenerarlo para aplicar el tema.)* |
| **Inicio de sesión (GDM)** | Logo y fondo de Core OS, tema oscuro. |
| **Escritorio** | Tema oscuro, iconos y acento de Core OS. |
| **Barra de tareas** | Centrada, **abajo**, botón "Inicio" (menú de aplicaciones) y apps ancladas: experiencia tipo Windows 11. |
| **App Store** | GNOME Software + Flatpak (sin la tienda de Ubuntu). |
| **Sin rastros de Ubuntu** | Sin telemetría, *onboarding* ni marca de Ubuntu; `os-release`, `issue`, `motd` y logo son de Core OS. |
| **Extras** | Acceso directo al Panel, Centro de bienvenida y Ajustes de Core OS. |

Los recursos gráficos (logo, fondo de GRUB, splash) se generan por código, sin
dependencias, con `customization/branding/tools/generate-assets.mjs`.

---

## Instalador propio (Core OS Setup, estilo Windows 11)

Al arrancar el medio de instalación, Core OS **no** muestra la pantalla de
Ubuntu: se lanza **Core OS Setup**, un asistente a pantalla completa con la
estética de Windows 11 que instala el sistema de verdad.

| Paso | Qué hace |
| --- | --- |
| 1. Configuración regional | Idioma, distribución del teclado y zona horaria. |
| 2. Instalar ahora | Pantalla de bienvenida con el logo de Core OS. |
| 3. Disco | Lista de discos y selección del destino (se formatea). |
| 4. Cuenta | Usuario, contraseña y nombre del equipo. |
| 5. Instalando… | Barra de progreso, consejos y detalle técnico. |
| 6. Fin | Reinicio a Core OS ya instalado. |

Por debajo, el asistente ([`customization/setup/`](./customization/setup)) es
una interfaz HTML/CSS/JS mostrada con WebKit2GTK y un backend Python que:

1. particiona (GPT: ESP + raíz; BIOS: `bios_grub` + raíz),
2. formatea (ext4 / FAT32) y monta,
3. copia el sistema con `rsync`,
4. configura `fstab`, locale, teclado, hostname y usuario,
5. instala **GRUB** (UEFI o BIOS) y habilita los servicios.

Se levanta como servicio (`core-os-setupd.service`, solo en el medio en vivo
gracias a `ConditionKernelCommandLine=boot=casper`) y se muestra a pantalla
completa en la sesión en vivo. En el sistema instalado **no** aparece.

---

## Vista previa en vivo (VNC)

`live-preview.yml` arranca la **ISO real** en una VM (QEMU/KVM) en CI y la
expone en el navegador con **noVNC** a través de un túnel público, además de
publicar capturas de pantalla en `<url>/shots/latest.png`. Es la forma de ver
e **interactuar** con el escritorio real sin instalar nada:

```bash
# Ejecuta el workflow "Live Preview" (o por API) e incluye el enlace noVNC
# en la página del run (Summary) y como artefacto `live-url`.
```

---

## Estructura del repositorio

```text
core-os/
├── .github/
│   └── workflows/
│       ├── build-iso.yml        # Empaqueta personalización + genera la ISO
│       ├── ci.yml               # Valida scripts y la app web en cada PR/push
│       └── deploy-web.yml       # Despliega el Modo Demo (Vercel)
├── customization/
│   ├── packages/                # Listas de paquetes a instalar / eliminar
│   ├── scripts/                 # Scripts de post-instalación (orden 00..99)
│   │   ├── 25-desktop-shell.sh  # Escritorio propio (barra tipo Windows 11)
│   │   └── 35-debrand-ubuntu.sh # GRUB/Plymouth/GDM con identidad Core OS
│   ├── systemd/                 # Unidades systemd (panel web)
│   ├── gnome/                   # dconf + extensiones de GNOME
│   ├── kde/                     # Perfil de Plasma (opcional)
│   ├── branding/                # Logos, wallpapers, GRUB, Plymouth y generador
│   │   └── tools/               # generate-assets.mjs (PNG sin dependencias)
│   ├── autoinstall/             # user-data / meta-data (Ubuntu Autoinstall)
│   ├── cubic/                   # Guía y hooks para Cubic
│   ├── iso-tools/               # Helpers de empaquetado (squashfs/xorriso)
│   ├── build-iso.sh             # Constructor de la ISO (modo script)
│   └── README.md
├── web-demo/                    # Modo Demo Web (admin panel)
│   ├── src/                     # Código del servidor (rutas y servicios)
│   ├── public/                  # Frontend (HTML/CSS/JS vanilla)
│   ├── data/                    # builds.json + logs de ejemplo
│   ├── server.js                # Punto de entrada (Render / local)
│   ├── api/index.js             # Handler serverless (Vercel)
│   ├── vercel.json              # Configuración de Vercel (Root Dir = web-demo)
│   └── Dockerfile
├── docs/                        # Arquitectura, guía Cubic, despliegue
├── render.yaml                  # Blueprint de Render.com (rootDir: web-demo)
└── README.md
```

---

## Inicio rápido

### 1. Modo Demo Web (no requiere Ubuntu ni Cubic)

```bash
cd web-demo
npm install
npm run dev            # -> http://localhost:3000
```

El dashboard funciona en **modo demo** por defecto: si no hay un Core OS real
detrás, genera métricas simuladas y sirve `data/builds.json` como historial.

> **Dentro de Core OS el panel es el mismo**, pero con métricas reales: al
> instalar la ISO, `scripts/45-web-demo.sh` instala Node.js, copia `web-demo/` a
> `/usr/lib/core-os/web-demo` y habilita el servicio `core-os-web-demo.service`.
> El panel queda accesible en **`http://<ip-del-equipo>:8080`**, idéntico a la
> versión web pero leyendo el sistema de verdad.

### 2. Construir la ISO de Core OS (en Ubuntu 22.04/24.04)

```bash
# Dependencias del host
sudo apt-get update
sudo apt-get install -y xorriso squashfs-tools rsync wget isolinux syslinux-utils

# Validar la personalización sin construir (rápido, sin permisos root)
sudo ./customization/build-iso.sh --dry-run

# Construcción completa (descarga la ISO base, ~6 GB, y la repaqueta)
sudo ./customization/build-iso.sh --release 1.0.0
```

Salida: `customization/out/core-os-1.0.0-amd64.iso`.

### 3. Cubic (alternativa gráfica, para desarrollo manual)

Ver [`docs/cubic-guide.md`](./docs/cubic-guide.md). Cubic es ideal para
**prototipar la personalización a mano**; el pipeline CI/CD usa el enfoque
**por scripts** (headless) que producen el mismo resultado de forma reproducible.

---

## Pipeline CI/CD

`build-iso.yml` se dispara con `push` a `main`, con tags `v*` y con
`workflow_dispatch`:

1. **validate** — `shellcheck` de los scripts + validación de las listas de paquetes.
2. **package** — empaqueta `customization/` en un tarball versionado (artefacto siempre disponible).
3. **build-iso** — descarga la ISO base de Ubuntu, la **monta**, remasteriza la
   capa base (`casper/minimal.squashfs`), ejecuta los scripts de personalización
   en un `chroot`, reempaqueta el `squashfs`, regenera los checksums y genera
   `core-os-<versión>-amd64.iso`.

Estado: **el pipeline pasa en verde y la ISO se construye correctamente**
(probado en GitHub Actions: `core-os-0.0.0+10-amd64.iso`, ~5.8 GB).

### Descargar la ISO

| Vía | Cómo |
| --- | --- |
| **Release (recomendado)** | `git tag v1.0.0 && git push origin v1.0.0` → se publica una Release con la ISO **dividida en partes <2 GB** (límite de GitHub). |
| **Artefacto del run** | Actions → *Build Core OS ISO* → run → *Artifacts* (`core-os-iso-*`); expira a los 7 días. |
| **Local** | `sudo ./customization/build-iso.sh --release 1.0.0` en Ubuntu 24.04. |

Para reconstruir la ISO desde las partes:

```bash
cat core-os-part-*.part > core-os-1.0.0-amd64.iso
sha256sum -c PARTS-SHA256SUMS   # o verifica contra SHA256SUMS
```

> ⚠️ Construir una ISO completa consume ~15-25 GB de disco y ~7 min en
> GitHub-hosted runners (gracias al paso de "liberar espacio"). Para iteración
> intensa se recomienda un runner self-hosted o construir en local.
>
> ℹ️ La ISO pesa ~6 GB y supera la cuota de artefactos de GitHub en algunos
> planes; por eso la subida es *best-effort* y la distribución real se hace por
> Release en partes.

---

## Identidad propia (resumen técnico)

| Capa | Implementación | Archivo |
| --- | --- | --- |
| Arranque | Tema GRUB con logo, fondo y `GRUB_DISTRIBUTOR="Core OS"` | `customization/branding/grub/`, `scripts/35-debrand-ubuntu.sh` |
| Splash | Tema Plymouth (`core-os`) con logo animado | `customization/branding/plymouth/` |
| Login | GDM con logo/fondo oscuros de Core OS | `scripts/35-debrand-ubuntu.sh` |
| Escritorio | Barra abajo centrada, botón Inicio, apps ancladas, tema oscuro | `scripts/25-desktop-shell.sh` |
| Sistema | `os-release`/`issue`/`motd` propios, sin telemetría de Ubuntu | `scripts/30-branding.sh`, `packages/remove.list` |
| Recursos | PNG generados por código (sin dependencias) | `branding/tools/generate-assets.mjs` |

---

## Despliegue del Modo Demo Web

| Plataforma | Rol | Config |
| --- | --- | --- |
| **Vercel** | Frontend + API serverless del dashboard | [`vercel.json`](./vercel.json) |
| **Render.com** | API/panel con métricas reales del host (`systeminformation`) | [`render.yaml`](./render.yaml) |
| **Docker** | Self-hosting en cualquier VPS | [`web-demo/Dockerfile`](./web-demo/Dockerfile) |

Guía paso a paso: [`docs/deploy.md`](./docs/deploy.md).

> Nota: en Vercel (serverless) las métricas reflejan el *contenedor* de la
> función, no tu Core OS. Para métricas reales del sistema, despliega la API en
> **Render** o en tu propia VPS con Docker.

---

## Roadmap

- [x] Estructura del repositorio y documentación
- [x] Scripts de personalización + autoinstall
- [x] Constructor de ISO reproducible (**verificado en CI**)
- [x] Workflow de CI/CD (empaquetado + ISO + Release en tags)
- [x] Identidad propia: GRUB, GDM y escritorio tipo Windows 11
- [x] **Instalador propio (Core OS Setup, estilo Windows 11)**
- [x] Modo Demo Web (dashboard, métricas, logs, terminal)
- [x] Vista previa en vivo por VNC (QEMU/KVM + noVNC)
- [ ] Splash de arranque propio (regenerar el `initrd` del medio)
- [ ] Firma de la ISO (GPG) y verificación de arranque seguro
- [ ] Repositorio APT propio (paquetes `core-os-*`)
- [ ] Autenticación del panel admin (OIDC / JWT)

## Licencia

MIT — ver [`LICENSE`](./LICENSE).
