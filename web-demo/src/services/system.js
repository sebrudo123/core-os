/**
 * services/system.js — Estado y métricas del sistema Core OS.
 *
 * - Si DEMO_MODE=false y el sistema soporta systeminformation, devuelve datos
 *   reales del host (ideal para el despliegue en Render o una VPS).
 * - Si no, genera métricas simuladas coherentes (útil en Vercel/serverless o
 *   para mostrar el panel sin un Core OS detrás).
 */
import fs from 'node:fs/promises';
import os from 'node:os';
import si from 'systeminformation';
import { config } from '../config.js';
import { logger } from '../logger.js';

// Estado del "paseo aleatorio" para métricas simuladas suaves.
const sim = { cpu: 18, mem: 42, disk: 37, net: 12 };

function jitter(value, min, max, step) {
  const next = value + (Math.random() - 0.5) * step;
  return Math.min(max, Math.max(min, next));
}

function round(n, d = 1) {
  const p = 10 ** d;
  return Math.round(n * p) / p;
}

function simulatedMetrics() {
  sim.cpu = jitter(sim.cpu, 3, 92, 14);
  sim.mem = jitter(sim.mem, 25, 88, 6);
  sim.disk = jitter(sim.disk, 30, 85, 0.4);
  sim.net = jitter(sim.net, 0.5, 120, 20);

  const totalMem = os.totalmem();
  const usedMem = (totalMem * sim.mem) / 100;

  return {
    simulated: true,
    timestamp: new Date().toISOString(),
    cpu: {
      usage: round(sim.cpu),
      cores: os.cpus().length || 4,
      model: os.cpus()[0]?.model?.trim() || 'Procesador simulado',
      loadAvg: os.loadavg().map((n) => round(n, 2)),
    },
    memory: {
      usage: round(sim.mem),
      totalBytes: totalMem,
      usedBytes: Math.round(usedMem),
      freeBytes: Math.round(totalMem - usedMem),
    },
    disk: {
      usage: round(sim.disk),
      totalBytes: 512 * 1024 ** 3,
      usedBytes: Math.round(512 * 1024 ** 3 * (sim.disk / 100)),
    },
    network: {
      rxMbps: round(sim.net * (0.6 + Math.random() * 0.4), 2),
      txMbps: round(sim.net * (0.3 + Math.random() * 0.3), 2),
    },
    uptimeSeconds: Math.round(process.uptime() + 3600 * 26),
  };
}

export async function getMetrics() {
  if (config.demoMode) return simulatedMetrics();

  try {
    const [load, mem, fsSize, net, time] = await Promise.all([
      si.currentLoad(),
      si.mem(),
      si.fsSize(),
      si.networkStats(),
      Promise.resolve(si.time()),
    ]);

    const root = fsSize.find((d) => d.mount === '/') || fsSize[0] || {};
    const net0 = Array.isArray(net) ? net[0] : net;
    const diskTotal = root.size || 0;
    const diskUsed = root.used || 0;

    return {
      simulated: false,
      timestamp: new Date().toISOString(),
      cpu: {
        usage: round(load.currentLoad),
        cores: os.cpus().length || 4,
        model: os.cpus()[0]?.model?.trim() || 'CPU',
        loadAvg: os.loadavg().map((n) => round(n, 2)),
      },
      memory: {
        usage: round((mem.active / mem.total) * 100),
        totalBytes: mem.total,
        usedBytes: mem.active,
        freeBytes: mem.available,
      },
      disk: {
        usage: diskTotal ? round((diskUsed / diskTotal) * 100) : 0,
        totalBytes: diskTotal,
        usedBytes: diskUsed,
      },
      network: {
        rxMbps: round(((net0?.rx_sec || 0) * 8) / 1e6, 2),
        txMbps: round(((net0?.tx_sec || 0) * 8) / 1e6, 2),
      },
      uptimeSeconds: time.uptime || Math.round(process.uptime()),
    };
  } catch (error) {
    logger.warn(`métricas reales no disponibles, usando simuladas: ${error.message}`);
    return { ...simulatedMetrics(), simulated: true, warning: error.message };
  }
}

/** Lee /etc/core-os/release si existe (sistema Core OS real). */
async function readCoreOsRelease() {
  try {
    const raw = await fs.readFile('/etc/core-os/release', 'utf8');
    const data = {};
    for (const line of raw.split('\n')) {
      const m = /^([A-Z_]+)="?(.*?)"?$/.exec(line.trim());
      if (m) data[m[1]] = m[2];
    }
    return data;
  } catch {
    return null;
  }
}

export async function getStatus() {
  const release = await readCoreOsRelease();
  let osInfo = { distro: config.coreOs.name, release: config.coreOs.release };
  let real = false;

  if (!config.demoMode) {
    try {
      const info = await si.osInfo();
      osInfo = { distro: info.distro, release: info.release, kernel: info.kernel, arch: info.arch };
      real = true;
    } catch (error) {
      logger.warn(`osInfo no disponible: ${error.message}`);
    }
  }

  const uptimeSeconds = os.uptime();

  return {
    ...osInfo,
    name: release?.CORE_OS_NAME || config.coreOs.name,
    version: release?.CORE_OS_RELEASE || config.coreOs.release,
    base: config.coreOs.base,
    codename: release?.CORE_OS_CODENAME || 'noble',
    simulated: config.demoMode,
    real: real && !config.demoMode,
    hostname: os.hostname(),
    arch: os.arch(),
    uptimeSeconds,
    node: process.version,
    platform: process.platform,
    services: [
      { name: 'ssh.service', status: 'active', enabled: true },
      { name: 'docker.service', status: 'active', enabled: true },
      { name: 'ufw.service', status: 'active', enabled: true },
      { name: 'fail2ban.service', status: 'active', enabled: true },
      { name: 'core-os-web-demo.service', status: 'active', enabled: true },
    ],
    goals: [
      { id: 'iso', label: 'ISO reproducible', progress: 100, state: 'done' },
      { id: 'branding', label: 'Branding + GNOME', progress: 100, state: 'done' },
      { id: 'ci', label: 'CI/CD GitHub Actions', progress: 100, state: 'done' },
      { id: 'web', label: 'Modo Demo Web', progress: 90, state: 'active' },
      { id: 'apt', label: 'Repositorio APT propio', progress: 20, state: 'pending' },
      { id: 'sign', label: 'Firma GPG de la ISO', progress: 0, state: 'pending' },
    ],
  };
}
