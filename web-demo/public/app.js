/**
 * app.js — Lógica del panel de administración de Core OS (frontend, vanilla JS).
 */
const API = '/api';

const state = {
  config: null,
  metrics: null,
  status: null,
  builds: [],
  logs: [],
  activeLog: null,
};

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => Array.from(document.querySelectorAll(sel));

/* ------------------------------------------------------------------ utils */
function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function formatBytes(bytes) {
  if (!bytes && bytes !== 0) return '—';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  let n = bytes;
  let i = 0;
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i += 1; }
  return `${n.toFixed(n < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}

function formatDuration(ms) {
  if (!ms) return '—';
  const s = Math.round(ms / 1000);
  const m = Math.floor(s / 60);
  return m > 0 ? `${m}m ${s % 60}s` : `${s}s`;
}

function formatUptime(seconds) {
  if (!seconds) return '—';
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d > 0) return `${d}d ${h}h ${m}m`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
}

function timeAgo(iso) {
  if (!iso) return '—';
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.round(diff / 60000);
  if (mins < 1) return 'hace instantes';
  if (mins < 60) return `hace ${mins} min`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `hace ${hours} h`;
  return `hace ${Math.round(hours / 24)} d`;
}

async function api(path, options) {
  const res = await fetch(`${API}${path}`, options);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  const type = res.headers.get('content-type') || '';
  return type.includes('application/json') ? res.json() : res.text();
}

function setConn(ok) {
  const el = $('#conn-status');
  el.textContent = ok ? 'conectado' : 'sin conexión';
  el.className = `pill ${ok ? 'pill-on' : 'pill-off'}`;
}

/* -------------------------------------------------------------- navegación */
const TITLES = {
  dashboard: ['Panel de administración', 'Estado del sistema Core OS en tiempo real'],
  builds: ['Compilaciones de la ISO', 'Pipeline de GitHub Actions y empaquetado'],
  logs: ['Logs de compilación', 'Salida de los procesos de build'],
  terminal: ['Terminal web', 'Comandos seguros con lista blanca'],
};

function showView(name) {
  $$('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.view === name));
  $$('.view').forEach((v) => v.classList.toggle('hidden', v.id !== `view-${name}`));
  const [title, subtitle] = TITLES[name] || ['Core OS', ''];
  $('#view-title').textContent = title;
  $('#view-subtitle').textContent = subtitle;
  if (name === 'builds') loadBuilds();
  if (name === 'logs') loadLogs();
}

/* --------------------------------------------------------------- dashboard */
function renderMetrics(m) {
  if (!m) return;
  state.metrics = m;

  const set = (id, pct, detail) => {
    $(`#m-${id}`).textContent = `${pct}%`;
    $(`#bar-${id}`).style.width = `${Math.min(100, pct)}%`;
    $(`#m-${id}-detail`).textContent = detail;
  };

  set('cpu', m.cpu.usage, `${m.cpu.cores} núcleos · carga ${m.cpu.loadAvg.join(' / ')}`);
  set('mem', m.memory.usage, `${formatBytes(m.memory.usedBytes)} de ${formatBytes(m.memory.totalBytes)}`);
  set('disk', m.disk.usage, `${formatBytes(m.disk.usedBytes)} de ${formatBytes(m.disk.totalBytes)}`);
  const netPct = Math.min(100, ((m.network.rxMbps + m.network.txMbps) / 2) * 10);
  set('net', Math.round(netPct), `↓ ${m.network.rxMbps} Mbps · ↑ ${m.network.txMbps} Mbps`);
}

function renderStatus(s) {
  if (!s) return;
  state.status = s;
  $('#host-chip').textContent = `host ${s.hostname}`;
  $('#brand-version').textContent = `v${s.version}`;

  const rows = [
    ['Distribución', s.distro || s.name],
    ['Versión', s.version],
    ['Base', s.base],
    ['Kernel', s.kernel || '6.8.0-core-os'],
    ['Arquitectura', s.arch],
    ['Hostname', s.hostname],
    ['Uptime', formatUptime(s.uptimeSeconds)],
    ['Node.js', s.node],
    ['Datos', s.simulated ? 'simulados (demo)' : 'reales del host'],
  ];
  $('#sys-info').innerHTML = rows
    .map(([k, v]) => `<dt>${escapeHtml(k)}</dt><dd>${escapeHtml(v)}</dd>`)
    .join('');

  $('#services').innerHTML = (s.services || [])
    .map(
      (svc) => `
      <li>
        <span><span class="dot ${svc.status === 'active' ? 'on' : ''}"></span>${escapeHtml(svc.name)}</span>
        <span class="muted small">${escapeHtml(svc.status)}${svc.enabled ? ' · enabled' : ''}</span>
      </li>`,
    )
    .join('');

  $('#goals').innerHTML = (s.goals || [])
    .map(
      (g) => `
      <li data-state="${escapeHtml(g.state)}">
        <span>${escapeHtml(g.label)}</span>
        <span class="bar"><i style="width:${g.progress}%"></i></span>
        <span class="pct">${g.progress}%</span>
      </li>`,
    )
    .join('');
}

async function loadMetrics() {
  try {
    renderMetrics(await api('/metrics'));
    setConn(true);
  } catch {
    setConn(false);
  }
}

async function loadStatus() {
  try {
    renderStatus(await api('/status'));
    setConn(true);
  } catch {
    setConn(false);
  }
}

/* ------------------------------------------------------------------ builds */
function renderBuildStats(stats) {
  if (!stats) return;
  const cards = [
    ['Total', stats.total],
    ['Éxito', `${stats.successRate}%`],
    ['En curso', stats.running],
    ['Duración media', formatDuration(stats.avgDurationMs)],
  ];
  $('#build-stats').innerHTML = cards
    .map(([lbl, num]) => `<article class="card stat"><div class="num">${escapeHtml(num)}</div><div class="lbl">${escapeHtml(lbl)}</div></article>`)
    .join('');
}

function renderBuilds(builds) {
  state.builds = builds;
  const body = $('#builds-body');
  if (!builds.length) {
    body.innerHTML = '<tr><td colspan="7" class="muted">Sin compilaciones registradas.</td></tr>';
    return;
  }
  body.innerHTML = builds
    .map(
      (b) => `
      <tr>
        <td class="mono">#${escapeHtml(b.runNumber ?? b.id)}</td>
        <td><span class="badge ${escapeHtml(b.status)}">${escapeHtml(b.status)}</span></td>
        <td class="mono">${escapeHtml(b.branch || '—')}</td>
        <td class="mono">${escapeHtml(b.commit || '—')}</td>
        <td>${formatDuration(b.durationMs)}</td>
        <td class="muted">${timeAgo(b.startedAt)}</td>
        <td><button class="btn small" data-log="${escapeHtml(b.id)}">log</button></td>
      </tr>`,
    )
    .join('');

  body.querySelectorAll('button[data-log]').forEach((btn) => {
    btn.addEventListener('click', () => openBuildLog(btn.dataset.log));
  });
}

async function loadBuilds() {
  try {
    const remote = $('#remote-toggle')?.checked ? 'true' : 'false';
    const data = await api(`/builds?limit=25&remote=${remote}`);
    renderBuildStats(data.stats);
    renderBuilds(data.builds);
    setConn(true);
  } catch {
    setConn(false);
  }
}

async function openBuildLog(id) {
  showView('logs');
  try {
    const data = await api(`/builds/${encodeURIComponent(id)}/logs`);
    $('#log-title').textContent = `build #${state.builds.find((b) => b.id === id)?.runNumber || id}`;
    $('#log-view').textContent = data.log || 'Sin logs disponibles para esta build.';
  } catch (error) {
    $('#log-view').textContent = `No se pudo cargar el log: ${error.message}`;
  }
}

/* -------------------------------------------------------------------- logs */
async function loadLogs() {
  try {
    const data = await api('/logs');
    state.logs = data.logs || [];
    const list = $('#log-list');
    if (!state.logs.length) {
      list.innerHTML = '<li class="muted">Sin archivos de log.</li>';
      return;
    }
    list.innerHTML = state.logs
      .map(
        (l) => `<li data-name="${escapeHtml(l.name)}" class="${state.activeLog === l.name ? 'active' : ''}">
          ${escapeHtml(l.name)}<span class="size">${formatBytes(l.sizeBytes)} · ${timeAgo(l.modifiedAt)}</span>
        </li>`,
      )
      .join('');
    list.querySelectorAll('li[data-name]').forEach((li) => {
      li.addEventListener('click', () => viewLog(li.dataset.name));
    });
  } catch {
    setConn(false);
  }
}

async function viewLog(name) {
  try {
    state.activeLog = name;
    const text = await api(`/logs/${encodeURIComponent(name)}`);
    $('#log-title').textContent = name;
    $('#log-view').textContent = text;
    $$('#log-list li').forEach((li) => li.classList.toggle('active', li.dataset.name === name));
  } catch (error) {
    $('#log-view').textContent = `Error: ${error.message}`;
  }
}

/* ---------------------------------------------------------------- terminal */
function appendTerminal(html) {
  const out = $('#terminal-output');
  out.innerHTML += html;
  out.scrollTop = out.scrollHeight;
}

async function runTerminalCommand(command) {
  appendTerminal(`<span class="cmd">coreadmin@core-os:~$ ${escapeHtml(command)}</span>\n`);
  try {
    const result = await api('/terminal', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command }),
    });
    if (result.clear) {
      $('#terminal-output').innerHTML = '';
      return;
    }
    const cls = result.error ? 'err' : '';
    appendTerminal(`<span class="${cls}">${escapeHtml(result.output)}</span>\n`);
  } catch (error) {
    appendTerminal(`<span class="err">error: ${escapeHtml(error.message)}</span>\n`);
  }
}

/* ------------------------------------------------------------------ config */
async function loadConfig() {
  try {
    const cfg = await api('/config');
    state.config = cfg;
    $('#brand-version').textContent = `v${cfg.coreOs.release}`;
    if (cfg.demoMode) $('#demo-badge').classList.remove('hidden');
  } catch {
    /* el panel sigue funcionando sin config */
  }
}

/* -------------------------------------------------------------------- init */
function bind() {
  $$('.nav-item').forEach((btn) => btn.addEventListener('click', () => showView(btn.dataset.view)));
  $('#refresh-btn').addEventListener('click', () => {
    loadStatus();
    loadMetrics();
    const active = $('.view:not(.hidden)')?.id;
    if (active === 'view-builds') loadBuilds();
    if (active === 'view-logs') loadLogs();
  });
  $('#remote-toggle')?.addEventListener('change', loadBuilds);
  $('#log-copy')?.addEventListener('click', async () => {
    await navigator.clipboard.writeText($('#log-view').textContent || '');
    $('#log-copy').textContent = '¡Copiado!';
    setTimeout(() => ($('#log-copy').textContent = 'Copiar'), 1200);
  });
  $('#terminal-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const input = $('#terminal-input');
    const command = input.value.trim();
    if (!command) return;
    input.value = '';
    runTerminalCommand(command);
  });
}

async function init() {
  bind();
  appendTerminal('<span class="ok">Bienvenido a la terminal segura de Core OS. Escribe "help".</span>\n');
  await loadConfig();
  await Promise.all([loadStatus(), loadMetrics()]);
  setInterval(loadMetrics, 5000);
}

init();
