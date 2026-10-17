/**
 * routes/logs.js — Listado y lectura de logs de compilación.
 */
import { Router } from 'express';
import { listLogs, readLog } from '../services/logs.js';

const router = Router();

router.get('/', async (_req, res, next) => {
  try {
    res.json({ logs: await listLogs() });
  } catch (error) {
    next(error);
  }
});

router.get('/:name', async (req, res, next) => {
  try {
    const tailLines = Number(req.query.tail) || 0;
    const log = await readLog(req.params.name, { tailLines });
    res.type('text/plain').send(log);
  } catch (error) {
    if (error.status === 400) return res.status(400).json({ error: error.message });
    if (error.code === 'ENOENT') return res.status(404).json({ error: 'log no encontrado' });
    next(error);
  }
});

export default router;
