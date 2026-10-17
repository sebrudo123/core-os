# Core OS

> Sistema operativo personalizado basado en **Ubuntu 24.04 LTS (Noble Numbat)**,
> con personalización automatizada (Cubic / scripts de chroot), pipeline CI/CD
> en GitHub Actions y un **Modo Demo Web** estilo CasaOS para administradores.

[![Build ISO](https://github.com/OWNER/core-os/actions/workflows/build-iso.yml/badge.svg)](../../actions/workflows/build-iso.yml)
[![CI](https://github.com/OWNER/core-os/actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

---

## ¿Qué es Core OS?

**Core OS** es una distribución derivada de Ubuntu pensada para administradores de
infraestructura: arranca con un escritorio limpio, herramientas de sistema ya
instaladas y un **panel de administración web** ("Modo Demo") que muestra el
estado del sistema, métricas, historial de compilaciones y una terminal segura.

El proyecto vive en dos grandes bloques:

| Bloque | Carpeta | Propósito |
| --- | --- | --- |
| **Personalización del SO** | [`customization/`](./customization) | Paquetes, tema, branding, scripts de post-instalación, autoinstall y el constructor de la ISO. |
| **Modo Demo Web** | [`web-demo/`](./web-demo) | El **panel de administración** de Core OS. Se instala dentro del SO (servicio systemd) y se despliega también en la web para previsualizarlo. |

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
│   ├── systemd/                 # Unidades systemd (panel web)
│   ├── gnome/                   # dconf + extensiones de GNOME
│   ├── kde/                     # Perfil de Plasma (opcional)
│   ├── branding/                # Logos, wallpapers, identidad
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

`build-iso.yml` se dispara con `push` a `main` (y `workflow_dispatch`):

1. **validate** — `shellcheck` de los scripts + validación de las listas de paquetes.
2. **package** — empaqueta `customization/` en un tarball versionado (artefacto siempre disponible).
3. **build-iso** — ejecuta `customization/build-iso.sh` en un runner Ubuntu,
   libera espacio en disco, genera la `.iso` y la sube como artefacto
   (y la adjunta a un Release si el push lleva un tag `v*`).

> ⚠️ Construir una ISO completa consume ~15-20 GB de disco y 20-40 min. En
> GitHub-hosted runners funciona con el paso de "liberar espacio", pero para
> iteración intensa se recomienda un runner self-hosted o construir en local.

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
- [x] Constructor de ISO reproducible
- [x] Workflow de CI/CD (empaquetado + ISO)
- [x] Modo Demo Web (dashboard, métricas, logs, terminal)
- [ ] Firma de la ISO (GPG) y verificación de arranque seguro
- [ ] Repositorio APT propio (paquetes `core-os-*`)
- [ ] Autenticación del panel admin (OIDC / JWT)

## Licencia

MIT — ver [`LICENSE`](./LICENSE).
