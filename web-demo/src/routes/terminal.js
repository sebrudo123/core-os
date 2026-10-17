/**
 * routes/terminal.js — Terminal web (lista blanca) del Modo Demo.
 */
import { Router } from 'express';
import { runCommand, availableCommands } from '../services/terminal.js';

const router = Router();

router.get('/commands', (_req, res) => {
  res.json({ commands: availableCommands() });
});

router.post('/', async (req, res, next) => {
  try {
    const { command } = req.body || {};
    const result = await runCommand(command);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;
