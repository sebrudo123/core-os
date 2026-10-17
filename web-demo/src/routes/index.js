/**
 * routes/index.js — Registra todas las rutas de la API bajo /api.
 */
import { Router } from 'express';
import statusRoutes from './status.js';
import metricsRoutes from './metrics.js';
import buildsRoutes from './builds.js';
import logsRoutes from './logs.js';
import terminalRoutes from './terminal.js';

export function registerRoutes(app) {
  const api = Router();

  api.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptimeSeconds: Math.round(process.uptime()) });
  });

  api.use('/', statusRoutes);
  api.use('/', metricsRoutes);
  api.use('/builds', buildsRoutes);
  api.use('/logs', logsRoutes);
  api.use('/terminal', terminalRoutes);

  app.use('/api', api);
}
