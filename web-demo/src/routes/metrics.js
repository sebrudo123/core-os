/**
 * routes/metrics.js — GET /api/metrics (métricas puntuales + stream SSE opcional)
 */
import { Router } from 'express';
import { getMetrics } from '../services/system.js';

const router = Router();

router.get('/metrics', async (_req, res, next) => {
  try {
    res.json(await getMetrics());
  } catch (error) {
    next(error);
  }
});

// Stream de métricas en tiempo real (Server-Sent Events).
router.get('/metrics/stream', async (req, res) => {
  res.set({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    Connection: 'keep-alive',
  });
  res.flushHeaders?.();

  const intervalMs = Math.max(1000, Number(req.query.interval || 2000));
  const timer = setInterval(async () => {
    try {
      const metrics = await getMetrics();
      res.write(`data: ${JSON.stringify(metrics)}\n\n`);
    } catch {
      res.write('event: error\ndata: {}\n\n');
    }
  }, intervalMs);

  req.on('close', () => clearInterval(timer));
});

export default router;
