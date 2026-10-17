# Core OS — Modo Demo Web

Panel de administración ligero (estilo CasaOS) para Core OS: estado del sistema,
métricas, historial de compilaciones, logs y una terminal web segura.

- **Stack**: Node.js + Express + frontend vanilla (sin frameworks).
- **Sin base de datos**: historial en `data/builds.json`, fusionado con GitHub Actions.
- **Dos modos**: demo (simulado) y real (métricas del host).

## Inicio rápido

```bash
npm install
npm run dev      # http://localhost:3000
```

Producción:

```bash
npm start
```

## Estructura

```text
web-demo/
├── server.js              # entrada local / Render
├── api/index.js           # handler serverless (Vercel)
├── src/
│   ├── app.js             # app Express (compartida)
│   ├── config.js          # configuración por env
│   ├── logger.js
│   ├── routes/            # status, metrics, builds, logs, terminal
│   └── services/          # lógica de negocio
├── public/                # SPA: index.html, styles.css, app.js
├── data/                  # builds.json + logs/
├── scripts/check.mjs      # comprobación de sintaxis (CI)
├── vercel.json            # despliegue en Vercel
└── Dockerfile             # self-hosting
```

## Vistas del panel

- **Panel**: CPU, memoria, disco, red, uptime, servicios y progreso del proyecto.
- **Compilaciones**: estadísticas + historial (local y de GitHub Actions).
- **Logs**: explorador y visor de logs de compilación.
- **Terminal**: comandos con lista blanca (`help` para ver la lista).

## Configuración

Toda la configuración se controla por variables de entorno. Ver
[`.env.example`](./.env.example) y [`docs/deploy.md`](../docs/deploy.md).

## Despliegue

| Plataforma | Comando / config |
| --- | --- |
| Vercel | Root Directory = `web-demo`, `vercel.json` incluido |
| Render | Blueprint en [`../render.yaml`](../render.yaml) (`rootDir: web-demo`) |
| Docker | `docker build -t core-os-web-demo . && docker run -p 3000:3000 core-os-web-demo` |

## API

Ver la tabla completa en [`docs/architecture.md`](../docs/architecture.md).

## Comprobaciones

```bash
npm run check     # sintaxis de todos los .js
```
