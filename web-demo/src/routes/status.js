/**
 * routes/status.js — GET /api/status y GET /api/config
 */
import { Router } from 'express';
import { getStatus } from '../services/system.js';
import { publicConfig } from '../config.js';

const router = Router();

router.get('/status', async (_req, res, next) => {
  try {
    res.json(await getStatus());
  } catch (error) {
    next(error);
  }
});

router.get('/config', (_req, res) => {
  res.json(publicConfig());
});

export default router;
