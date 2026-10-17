/**
 * services/logs.js — Lectura de logs de compilación.
 * Los logs viven en data/logs/*.log y se sirven al panel de administración.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { config } from '../config.js';
import { logger } from '../logger.js';

const LOGS_DIR = config.paths.logsDir;

/** Evita path traversal: sólo nombres simples terminados en .log. */
function safeName(name) {
  const base = path.basename(String(name || ''));
  if (!/^[a-zA-Z0-9._-]+\.log$/.test(base)) {
    throw Object.assign(new Error('nombre de log inválido'), { status: 400 });
  }
  return base;
}

export async function listLogs() {
  try {
    const entries = await fs.readdir(LOGS_DIR);
    const logs = [];
    for (const entry of entries) {
      if (!entry.endsWith('.log')) continue;
      const full = path.join(LOGS_DIR, entry);
      const stat = await fs.stat(full);
      logs.push({
        name: entry,
        sizeBytes: stat.size,
        modifiedAt: stat.mtime.toISOString(),
      });
    }
    logs.sort((a, b) => new Date(b.modifiedAt) - new Date(a.modifiedAt));
    return logs;
  } catch (error) {
    logger.warn(`no se pudo listar logs: ${error.message}`);
    return [];
  }
}

export async function readLog(name, { tailLines = 0 } = {}) {
  const safe = safeName(name);
  const full = path.join(LOGS_DIR, safe);
  const raw = await fs.readFile(full, 'utf8');
  if (tailLines > 0) {
    const lines = raw.split('\n');
    return lines.slice(-tailLines).join('\n');
  }
  return raw;
}
