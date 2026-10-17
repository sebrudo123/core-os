/**
 * config.js — Configuración central del Modo Demo Web de Core OS.
 * Toda la configuración se controla por variables de entorno (ver .env.example).
 */
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const ROOT_DIR = path.resolve(__dirname, '..');

/** Convierte "true/1/yes" en true. */
function toBool(value, fallback = false) {
  if (value === undefined || value === null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on', 'si', 'sí'].includes(String(value).toLowerCase());
}

export const config = {
  port: Number(process.env.PORT || 3000),

  // Modo demo: si no hay un Core OS real detrás, se generan datos simulados.
  demoMode: toBool(process.env.DEMO_MODE, true),

  // Ejecutar comandos reales en la terminal web (desactivado por defecto).
  allowTerminal: toBool(process.env.ALLOW_TERMINAL, false),

  // Integración con GitHub (historial real de builds de Actions).
  github: {
    repo: process.env.GITHUB_REPO || 'core-os/core-os',
    token: process.env.GITHUB_TOKEN || '',
    branch: process.env.GITHUB_BRANCH || 'main',
  },

  coreOs: {
    name: 'Core OS',
    release: process.env.CORE_OS_RELEASE || '1.0.0',
    base: process.env.CORE_OS_BASE || 'Ubuntu 24.04 LTS (noble)',
    repository: process.env.CORE_OS_REPOSITORY || 'https://github.com/core-os/core-os',
  },

  paths: {
    rootDir: ROOT_DIR,
    publicDir: path.join(ROOT_DIR, 'public'),
    dataDir: path.join(ROOT_DIR, 'data'),
    logsDir: path.join(ROOT_DIR, 'data', 'logs'),
  },
};

/** Configuración segura para exponer al frontend (sin secretos). */
export function publicConfig() {
  return {
    demoMode: config.demoMode,
    allowTerminal: config.allowTerminal,
    coreOs: config.coreOs,
    github: { repo: config.github.repo, branch: config.github.branch },
    version: process.env.npm_package_version || '1.0.0',
  };
}
