# Arquitectura de Core OS

## Visión general

```text
                ┌──────────────────────────────────────────────┐
                │                  GitHub                       │
                │  push a main ──► Actions (build-iso.yml)      │
                │                    │                          │
                │                    ├─ validate (shellcheck)   │
                │                    ├─ package (tarball)       │
                │                    └─ build-iso ──► .iso      │
                └──────────────────────────────────────────────┘
                                    │
             customization/         │            web-demo/
        (se empaqueta en la ISO)    │     (panel de administración)
                                    ▼            │
                          ┌──────────────┐       │  Vercel  → vista previa pública (demo)
                          │  Core OS ISO │       ├─►
                          │  Ubuntu base │       │  Render  → vista previa con métricas reales
                          └──────┬───────┘       └─►
                                 │ instalación
                                 ▼
                     ┌────────────────────────────┐
                     │  Core OS instalado          │
                     │  └─ core-os-web-demo.service│  ← MISMO panel, métricas reales
                     │     http://<host>:8080      │     (DEMO_MODE=false)
                     └────────────────────────────┘
```

> El panel es **el mismo código** en los tres entornos. `45-web-demo.sh` lo
> instala dentro del SO (Node.js + systemd, puerto 8080); Vercel y Render solo
> sirven la misma app como vista previa para administradores.

## Componentes

### 1. Personalización (`customization/`)

- **Fuente de verdad** de todo lo que se instala y configura.
- Scripts numerados que se ejecutan dentro de un `chroot` (mismo resultado en
  Cubic o en `build-iso.sh`).
- Listas declarativas de paquetes (`packages.list` / `remove.list`).
- `build-iso.sh` orquesta: descarga → extrae → chroot → repaqueta.

Flujo interno de `build-iso.sh`:

```text
 ISO base ──xorriso extract──► work/iso
                                   │
                                   ├─ casper/filesystem.squashfs
                                   │        │ unsquashfs
                                   │        ▼
                                   │     work/edit  ◄── rsync customization → /opt/core-os
                                   │        │
                                   │        ├─ bind /proc /sys /dev /run
                                   │        ├─ chroot: scripts/00..99
                                   │        └─ mksquashfs → filesystem.squashfs
                                   │
                                   └─ xorriso mkisofs ──► out/core-os-<v>-amd64.iso
```

### 2. Modo Demo Web (`web-demo/`)

Aplicación **Node.js + Express** con una SPA de un solo archivo (sin framework)
para minimizar dependencias y facilitar el despliegue.

Forma parte de la ISO: `scripts/45-web-demo.sh` instala Node.js, copia la app a
`/usr/lib/core-os/web-demo`, crea `/etc/core-os/web-demo.env` y habilita el
servicio `core-os-web-demo.service` (puerto 8080). Así, el panel que se ve en la
web y el que se ejecuta en el sistema instalado son **exactamente el mismo**.

```text
public/ (SPA: index.html, styles.css, app.js)
   │ fetch /api/*
   ▼
src/app.js ──► src/routes/*  ──► src/services/*
     (Express)      │                 ├── system.js   (métricas / estado)
                    │                 ├── builds.js   (historial)
                    │                 ├── github.js   (GitHub Actions)
                    │                 ├── logs.js     (lectura de logs)
                    │                 └── terminal.js (lista blanca)
```

Dos modos de operación:

| Modo | `DEMO_MODE` | Datos | Dónde encaja |
| --- | --- | --- | --- |
| Demo | `true` | Simulados (deterministas) | Vercel, demos, portafolio |
| Real | `false` | Del host vía `systeminformation` | Render, VPS, propio Core OS |

### 3. Endpoints de la API

| Método | Ruta | Descripción |
| --- | --- | --- |
| GET | `/api/health` | Estado básico del servicio |
| GET | `/api/config` | Configuración pública (sin secretos) |
| GET | `/api/status` | Identidad del SO, servicios, roadmap |
| GET | `/api/metrics` | CPU, memoria, disco, red, uptime |
| GET | `/api/metrics/stream` | Métricas en vivo (SSE) |
| GET | `/api/builds` | Historial + estadísticas |
| GET | `/api/builds/:id` | Detalle de una build |
| GET | `/api/builds/:id/logs` | Log de una build |
| GET | `/api/logs` | Lista de archivos de log |
| GET | `/api/logs/:name` | Contenido de un log |
| GET | `/api/terminal/commands` | Comandos permitidos |
| POST | `/api/terminal` | Ejecuta un comando (lista blanca) |

## Decisiones de diseño

- **Cubic vs scripts**: Cubic (GUI) para prototipar; `build-iso.sh` (headless)
  para CI/CD. Ambos aplican los mismos scripts → una sola fuente de verdad.
- **Sin shell en la terminal web**: se usa `execFile` con lista blanca, sin
  interpretación de shell, para eliminar inyección de comandos.
- **Sin base de datos**: el historial vive en `data/builds.json` y se fusiona con
  la API de GitHub Actions. Menos infraestructura, más portabilidad.
- **Un solo artefacto para Vercel y Render**: `src/app.js` se exporta tanto al
  servidor clásico como al handler serverless.

## Seguridad (estado actual y pendientes)

- [x] Terminal con lista blanca y sin shell.
- [x] Path traversal bloqueado en la lectura de logs.
- [x] Secretos sólo por variables de entorno (`.env` ignorado por git).
- [ ] Autenticación del panel admin (OIDC / JWT) — roadmap.
- [ ] Rate limiting y CSRF — roadmap.
- [ ] Firma GPG de la ISO — roadmap.
