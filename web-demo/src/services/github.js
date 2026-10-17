/**
 * services/github.js — Integración de solo-lectura con GitHub Actions.
 * Obtiene el historial real de ejecuciones del workflow de build de la ISO.
 */
import { config } from '../config.js';
import { logger } from '../logger.js';

const API = 'https://api.github.com';

async function ghFetch(pathname) {
  const headers = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'core-os-web-demo',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  if (config.github.token) headers.Authorization = `Bearer ${config.github.token}`;

  const res = await fetch(`${API}${pathname}`, { headers });
  if (!res.ok) {
    throw new Error(`GitHub API ${res.status} ${res.statusText}`);
  }
  return res.json();
}

/** Devuelve las últimas ejecuciones del workflow como builds normalizadas. */
export async function fetchWorkflowRuns(limit = 10) {
  const repo = config.github.repo;
  if (!repo || !repo.includes('/')) return [];
  try {
    const data = await ghFetch(`/repos/${repo}/actions/runs?per_page=${limit}`);
    return (data.workflow_runs || []).map(normalizeRun);
  } catch (error) {
    logger.warn(`no se pudo consultar GitHub Actions: ${error.message}`);
    return [];
  }
}

export function normalizeRun(run) {
  const startedAt = run.run_started_at || run.created_at;
  const finishedAt = run.updated_at;
  const durationMs =
    startedAt && finishedAt ? new Date(finishedAt) - new Date(startedAt) : 0;

  return {
    id: String(run.id),
    runNumber: run.run_number,
    version: run.head_branch === 'main' ? run.head_sha.slice(0, 7) : run.head_branch,
    status: mapStatus(run.status, run.conclusion),
    branch: run.head_branch,
    commit: run.head_sha ? run.head_sha.slice(0, 7) : null,
    commitMessage: run.head_commit?.message?.split('\n')[0] || null,
    actor: run.actor?.login || null,
    workflow: run.name,
    startedAt,
    finishedAt,
    durationMs,
    url: run.html_url,
    source: 'github',
  };
}

function mapStatus(status, conclusion) {
  if (status === 'completed') {
    if (conclusion === 'success') return 'success';
    if (conclusion === 'cancelled') return 'cancelled';
    return 'failed';
  }
  if (status === 'in_progress') return 'running';
  return 'queued';
}
