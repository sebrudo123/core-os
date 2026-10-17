/**
 * services/builds.js — Historial de compilaciones de la ISO de Core OS.
 *
 * Fuente 1: data/builds.json (historial local de ejemplo).
 * Fuente 2: GitHub Actions (si hay red/token), se fusionan y ordenan.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { config } from '../config.js';
import { logger } from '../logger.js';
import { fetchWorkflowRuns } from './github.js';

const BUILDS_FILE = path.join(config.paths.dataDir, 'builds.json');

export async function getLocalBuilds() {
  try {
    const raw = await fs.readFile(BUILDS_FILE, 'utf8');
    const data = JSON.parse(raw);
    return Array.isArray(data) ? data : data.builds || [];
  } catch (error) {
    logger.warn(`no se pudo leer builds.json: ${error.message}`);
    return [];
  }
}

export async function getBuilds({ limit = 20, includeRemote = true } = {}) {
  const local = await getLocalBuilds();
  let remote = [];
  if (includeRemote) remote = await fetchWorkflowRuns(limit);

  // Fusiona: primero los de GitHub (reales), luego los locales que no dupliquen.
  const seen = new Set(remote.map((b) => b.id));
  const merged = [
    ...remote,
    ...local.filter((b) => !seen.has(b.id)),
  ];

  merged.sort((a, b) => new Date(b.startedAt || 0) - new Date(a.startedAt || 0));
  return merged.slice(0, limit);
}

export async function getBuildById(id) {
  const builds = await getBuilds({ limit: 50 });
  return builds.find((b) => b.id === id) || null;
}

/** Estadísticas agregadas para el panel. */
export async function getBuildStats() {
  const builds = await getBuilds({ limit: 50 });
  const total = builds.length;
  const success = builds.filter((b) => b.status === 'success').length;
  const failed = builds.filter((b) => b.status === 'failed').length;
  const running = builds.filter((b) => b.status === 'running' || b.status === 'queued').length;
  const durations = builds.filter((b) => b.durationMs > 0).map((b) => b.durationMs);
  const avgDurationMs = durations.length
    ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length)
    : 0;

  return {
    total,
    success,
    failed,
    running,
    successRate: total ? Math.round((success / total) * 100) : 0,
    avgDurationMs,
    lastBuild: builds[0] || null,
  };
}
