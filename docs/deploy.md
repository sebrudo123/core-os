# Guía de despliegue del Modo Demo Web

La app de `web-demo/` se puede desplegar en **Vercel**, **Render.com** o tu
propia **VPS con Docker**. El mismo código sirve para las tres.

> 🖥️ **En Core OS ya viene instalado.** `scripts/45-web-demo.sh` copia la app a
> `/usr/lib/core-os/web-demo`, crea `/etc/core-os/web-demo.env` y habilita
> `core-os-web-demo.service`. Tras instalar la ISO: **`http://<ip>:8080`**.
> Las opciones siguientes son para la **vista previa pública** del mismo panel.

---

## Opción A — Vercel (frontend + API serverless) · recomendado para la demo

Vercel ejecuta cada petición en un entorno serverless. Es perfecto para mostrar
el panel públicamente, pero las **métricas son simuladas** (no hay un host fijo),
por lo que conviene `DEMO_MODE=true`.

### Pasos

1. Entra en [vercel.com/new](https://vercel.com/new) e importa el repositorio.
2. **Root Directory**: `web-demo` (importante).
3. Framework Preset: **Other**.
4. Variables de entorno:
   - `DEMO_MODE=true`
   - `GITHUB_REPO=<owner>/core-os` (opcional, para builds reales)
   - `GITHUB_TOKEN=<token>` (opcional)
5. Deploy.

La configuración ya está en `web-demo/vercel.json`:

```json
{
  "rewrites": [{ "source": "/(.*)", "destination": "/api" }],
  "functions": { "api/index.js": { "includeFiles": "public/**" } }
}
```

### Despliegue automático con GitHub Actions

El workflow `.github/workflows/deploy-web.yml` despliega en cada push a `main`.
Añade estos **secrets** en `Settings > Secrets and variables > Actions`:

| Secret | Dónde obtenerlo |
| --- | --- |
| `VERCEL_TOKEN` | vercel.com/account/tokens |
| `VERCEL_ORG_ID` | `.vercel/project.json` tras `vercel link` |
| `VERCEL_PROJECT_ID` | `.vercel/project.json` tras `vercel link` |

Sin esos secrets, el workflow no falla: se omite el deploy.

---

## Opción B — Render.com (API + métricas REALES)

Render ejecuta un proceso Node persistente → `systeminformation` lee el host real.

1. [dashboard.render.com](https://dashboard.render.com) → **New** → **Blueprint**.
2. Selecciona el repositorio: Render detecta `render.yaml`.
3. Configura las variables marcadas como secretas (`GITHUB_REPO`, `GITHUB_TOKEN`).
4. Deploy. La URL será algo como `https://core-os-web-demo.onrender.com`.

`render.yaml` ya define `rootDir: web-demo`, el comando de arranque y el
healthcheck en `/api/health`.

> El plan gratuito de Render "duerme" tras 15 min de inactividad; el primer
> acceso tras dormir tarda unos segundos.

---

## Opción C — VPS propia con Docker

```bash
cd web-demo
docker build -t core-os-web-demo .
docker run -d --name core-os-web \
  -p 3000:3000 \
  -e DEMO_MODE=false \
  -e ALLOW_TERMINAL=false \
  -e GITHUB_REPO=<owner>/core-os \
  core-os-web-demo
```

Abre `http://<ip-de-tu-vps>:3000`.

> Con `DEMO_MODE=false` y corriendo en el propio Core OS, el panel muestra
> métricas reales del sistema.

---

## Desarrollo local

```bash
cd web-demo
npm install
cp .env.example .env      # opcional
npm run dev               # http://localhost:3000
```

### Variables de entorno

| Variable | Por defecto | Descripción |
| --- | --- | --- |
| `PORT` | `3000` | Puerto HTTP |
| `DEMO_MODE` | `true` | `true` simula métricas; `false` lee el host real |
| `ALLOW_TERMINAL` | `false` | Habilita comandos reales (lista blanca) |
| `GITHUB_REPO` | `core-os/core-os` | `owner/repo` para el historial de builds |
| `GITHUB_TOKEN` | — | Token opcional (rate limit / repos privados) |
| `CORE_OS_RELEASE` | `1.0.0` | Versión mostrada en el panel |
| `LOG_LEVEL` | `info` | `debug`\|`info`\|`warn`\|`error` |

---

## Endpoints útiles para probar

```bash
curl localhost:3000/api/health
curl localhost:3000/api/status
curl localhost:3000/api/metrics
curl localhost:3000/api/builds
curl -X POST localhost:3000/api/terminal \
  -H 'Content-Type: application/json' -d '{"command":"help"}'
```
