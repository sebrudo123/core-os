/**
 * app.js — Construye la aplicación Express de Core OS Web Demo.
 * Se exporta tanto para el servidor clásico (server.js / Render) como para
 * el handler serverless de Vercel (api/index.js).
 */
import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import cors from 'cors';
import { config } from './config.js';
import { logger, requestLogger } from './logger.js';
import { registerRoutes } from './routes/index.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);

  app.use(cors());
  app.use(express.json({ limit: '256kb' }));
  app.use(requestLogger);

  // --- API ---
  registerRoutes(app);

  // --- Frontend estático ---
  const indexHtml = path.join(config.paths.publicDir, 'index.html');
  if (fs.existsSync(config.paths.publicDir)) {
    app.use(express.static(config.paths.publicDir, { extensions: ['html'] }));
  }

  // Fallback SPA: cualquier ruta no-API devuelve el panel.
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api')) return next();
    if (fs.existsSync(indexHtml)) return res.sendFile(indexHtml);
    return res
      .status(200)
      .type('html')
      .send('<h1>Core OS — Modo Demo Web</h1><p>El frontend (public/) no está disponible.</p>');
  });

  // Manejador de errores.
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    logger.error(err.stack || err.message);
    res.status(err.status || 500).json({ error: err.message || 'Error interno' });
  });

  return app;
}

const app = createApp();
export default app;
