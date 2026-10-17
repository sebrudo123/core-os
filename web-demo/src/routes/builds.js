/**
 * routes/builds.js — Historial y estado de las compilaciones de la ISO.
 */
import { Router } from 'express';
import { getBuilds, getBuildById, getBuildStats } from '../services/builds.js';
import { listLogs, readLog } from '../services/logs.js';

const router = Router();

router.get('/', async (req, res, next) => {
  try {
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
    const includeRemote = req.query.remote !== 'false';
    const [builds, stats] = await Promise.all([
      getBuilds({ limit, includeRemote }),
      getBuildStats(),
    ]);
    res.json({ stats, builds });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const build = await getBuildById(req.params.id);
    if (!build) return res.status(404).json({ error: 'build no encontrada' });
    res.json(build);
  } catch (error) {
    next(error);
  }
});

// Log simulado/en vivo de una build concreta.
router.get('/:id/logs', async (req, res, next) => {
  try {
    const build = await getBuildById(req.params.id);
    if (!build) return res.status(404).json({ error: 'build no encontrada' });
    const logs = await listLogs();
    const match = logs.find((l) => l.name.includes(String(build.runNumber || '')));
    const text = match ? await readLog(match.name) : build.defaultLog || null;
    res.json({ buildId: build.id, name: match?.name || null, log: text });
  } catch (error) {
    next(error);
  }
});

export default router;
