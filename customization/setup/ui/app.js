/* ==========================================================================
   Core OS Setup — lógica de la interfaz (asistente de 4 pasos)
   ========================================================================== */
'use strict';

const $ = (sel) => document.querySelector(sel);

const state = {
  page: 1,
  disk: null,
  uefi: false,
  installing: false,
};

const els = {
  steps: [...document.querySelectorAll('.step')],
  pages: [...document.querySelectorAll('.page')],
  disks: $('#disks'),
  firmwareHint: $('#firmware-hint'),
  confirmErase: $('#confirm-erase'),
  back: $('#back'),
  next: $('#next'),
  install: $('#install'),
  reboot: $('#reboot'),
  status: $('#status'),
  bar: $('#bar'),
  percent: $('#percent'),
  message: $('#progress-message'),
  progressTitle: $('#progress-title'),
  log: $('#log'),
  version: $('#version'),
};

/* ----------------------------- utilidades ------------------------------- */
function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[c]);
}

function setStatus(text) {
  els.status.textContent = text || '';
}

function goTo(page) {
  state.page = page;
  for (const el of els.pages) {
    el.classList.toggle('is-active', Number(el.dataset.page) === page);
  }
  for (const el of els.steps) {
    const n = Number(el.dataset.step);
    el.classList.toggle('is-active', n === page);
    el.classList.toggle('is-done', n < page);
  }
  els.back.classList.toggle('is-hidden', page <= 1 || state.installing);
  els.back.disabled = state.installing;
  els.next.classList.toggle('is-hidden', page >= 3 || page === 4 || state.installing);
  els.install.classList.toggle('is-hidden', page !== 3 || state.installing);
  els.reboot.classList.add('is-hidden');
  if (page === 2) validateDiskStep();
  if (page === 3) validateAccountStep();
}

/* ------------------------------ discos ---------------------------------- */
async function loadSystem() {
  try {
    const res = await fetch('/api/system');
    const data = await res.json();
    state.uefi = Boolean(data.uefi);
    if (data.version) els.version.textContent = `Core OS ${data.version}`;
    els.firmwareHint.textContent = state.uefi
      ? 'Arranque UEFI detectado. Se creará una partición de arranque EFI.'
      : 'Arranque BIOS detectado. Se instalará GRUB en el disco elegido.';
    renderDisks(data.disks || []);
  } catch (err) {
    els.disks.innerHTML = '<p class="muted">No se pudieron leer los discos.</p>';
  }
}

function renderDisks(disks) {
  if (!disks.length) {
    els.disks.innerHTML = '<p class="muted">No se ha encontrado ningún disco.</p>';
    return;
  }
  els.disks.innerHTML = disks.map((d) => `
    <button type="button" class="disk" data-device="${escapeHtml(d.device)}"
            data-label="${escapeHtml(d.model)} — ${escapeHtml(d.size)}">
      <svg class="disk__icon" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="currentColor" d="M4 5h16a1 1 0 0 1 1 1v7H3V6a1 1 0 0 1 1-1Zm-1 10h18v4a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-4Zm3.5 2.5a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"/>
      </svg>
      <span>
        <span class="disk__name">${escapeHtml(d.device)}</span>
        <span class="disk__meta">${escapeHtml(d.model)} · ${escapeHtml(d.size)}${
          d.rotational ? ' · disco duro' : ' · SSD'}${d.removable ? ' · extraíble' : ''}</span>
      </span>
    </button>
  `).join('');

  for (const btn of els.disks.querySelectorAll('.disk')) {
    btn.addEventListener('click', () => {
      state.disk = { device: btn.dataset.device, label: btn.dataset.label };
      for (const other of els.disks.querySelectorAll('.disk')) {
        other.classList.toggle('is-selected', other === btn);
      }
      validateDiskStep();
    });
  }
}

function validateDiskStep() {
  const ok = Boolean(state.disk) && els.confirmErase.checked;
  els.next.disabled = !ok;
  if (!state.disk) setStatus('Selecciona el disco donde instalar Core OS.');
  else if (!els.confirmErase.checked) setStatus('Marca la casilla para confirmar el borrado del disco.');
  else setStatus(`Se instalará en ${state.disk.device}.`);
  return ok;
}

/* ------------------------------ cuenta ---------------------------------- */
function accountValues() {
  return {
    locale: $('#locale').value,
    keymap: $('#keymap').value,
    timezone: $('#timezone').value,
    user: $('#user').value.trim(),
    password: $('#password').value,
    password2: $('#password2').value,
    hostname: $('#hostname').value.trim(),
  };
}

function validateAccountStep() {
  const v = accountValues();
  let error = '';
  if (!/^[a-z][a-z0-9_-]{1,31}$/.test(v.user)) {
    error = 'El usuario debe empezar por letra y usar solo minúsculas, números, «-» o «_».';
  } else if (v.password.length < 1) {
    error = 'Escribe una contraseña.';
  } else if (v.password !== v.password2) {
    error = 'Las contraseñas no coinciden.';
  } else if (!/^[a-zA-Z0-9-]{1,63}$/.test(v.hostname)) {
    error = 'El nombre del equipo solo admite letras, números y «-».';
  }
  els.install.disabled = Boolean(error);
  setStatus(error);
  return !error;
}

/* ---------------------------- instalación ------------------------------- */
async function startInstall() {
  if (!validateAccountStep()) return;
  const v = accountValues();
  state.installing = true;
  goTo(4);
  els.progressTitle.textContent = 'Instalando Core OS…';
  els.message.textContent = 'Preparando…';
  els.log.textContent = '';

  await fetch('/api/install', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      disk: state.disk.device,
      locale: v.locale,
      keymap: v.keymap,
      timezone: v.timezone,
      user: v.user,
      password: v.password,
      hostname: v.hostname,
    }),
  });

  poll();
}

async function poll() {
  let data;
  try {
    data = await (await fetch('/api/progress')).json();
  } catch (err) {
    setTimeout(poll, 1500);
    return;
  }

  els.bar.style.width = `${data.percent || 0}%`;
  els.percent.textContent = `${data.percent || 0} %`;
  els.message.textContent = data.message || '';
  if (Array.isArray(data.log)) {
    els.log.textContent = data.log.join('\n');
    els.log.scrollTop = els.log.scrollHeight;
  }

  if (data.error) {
    els.progressTitle.textContent = 'La instalación ha fallado';
    els.message.textContent = data.error;
    state.installing = false;
    els.reboot.classList.remove('is-hidden');
    return;
  }

  if (data.done) {
    els.progressTitle.textContent = 'Core OS está instalado';
    els.message.textContent = 'Retira el medio de instalación y reinicia para empezar a usar Core OS.';
    els.bar.style.width = '100%';
    els.percent.textContent = '100 %';
    state.installing = false;
    els.reboot.classList.remove('is-hidden');
    return;
  }

  setTimeout(poll, 1000);
}

/* ------------------------------- eventos -------------------------------- */
els.next.addEventListener('click', () => {
  if (state.page === 1) return goTo(2);
  if (state.page === 2 && validateDiskStep()) return goTo(3);
});

els.back.addEventListener('click', () => {
  if (state.page > 1) goTo(state.page - 1);
});

els.install.addEventListener('click', startInstall);

els.reboot.addEventListener('click', async () => {
  els.reboot.disabled = true;
  setStatus('Reiniciando…');
  try { await fetch('/api/reboot', { method: 'POST' }); } catch (err) { /* ignora */ }
});

els.confirmErase.addEventListener('change', validateDiskStep);

for (const id of ['#user', '#password', '#password2', '#hostname']) {
  $(id).addEventListener('input', validateAccountStep);
}

goTo(1);
loadSystem();
