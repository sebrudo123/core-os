/**
 * services/terminal.js — Terminal web con lista blanca.
 *
 * Modo demo (por defecto): devuelve salidas simuladas deterministas para que
 * cualquier persona pueda "probar" el sistema desde el navegador.
 * Modo real (ALLOW_TERMINAL=true y DEMO_MODE=false): ejecuta SÓLO los comandos
 * de la lista blanca, sin shell, sin tuberías y sin redirecciones.
 */
import { execFile } from 'node:child_process';
import os from 'node:os';
import { config } from '../config.js';
import { logger } from '../logger.js';

const HELP = [
  'Comandos disponibles en el Modo Demo:',
  '  help              Muestra esta ayuda',
  '  core-os version   Versión de Core OS',
  '  uname -a          Información del kernel',
  '  uptime            Tiempo encendido',
  '  free -h           Uso de memoria',
  '  df -h             Uso de disco',
  '  lsbd              Release de Core OS',
  '  whoami            Usuario actual',
  '  hostname          Nombre del host',
  '  date              Fecha y hora',
  '  status            Resumen de servicios',
  '  clear             Limpia la terminal',
].join('\n');

// Lista blanca: clave -> { file, args }
const ALLOWLIST = new Map([
  ['uname -a', { file: 'uname', args: ['-a'] }],
  ['uname', { file: 'uname', args: ['-a'] }],
  ['uptime', { file: 'uptime', args: [] }],
  ['free -h', { file: 'free', args: ['-h'] }],
  ['free', { file: 'free', args: ['-h'] }],
  ['df -h', { file: 'df', args: ['-h'] }],
  ['df', { file: 'df', args: ['-h'] }],
  ['whoami', { file: 'whoami', args: [] }],
  ['hostname', { file: 'hostname', args: [] }],
  ['date', { file: 'date', args: [] }],
  ['lsb_release -a', { file: 'lsb_release', args: ['-a'] }],
]);

function simulated(command) {
  const cmd = command.trim();
  const host = os.hostname();
  const table = {
    help: HELP,
    'core-os version': `${config.coreOs.name} ${config.coreOs.release} (base ${config.coreOs.base})`,
    'core-os': `${config.coreOs.name} ${config.coreOs.release} (base ${config.coreOs.base})`,
    'uname -a': `Linux ${host} 6.8.0-core-os #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux`,
    uname: `Linux ${host} 6.8.0-core-os #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux`,
    uptime: ` ${new Date().toLocaleTimeString()} up 26 days,  3:14,  1 user,  load average: 0.42, 0.35, 0.31`,
    'free -h': '               total        used        free      shared  buff/cache   available\nMem:            15Gi       6.3Gi       4.1Gi       412Mi       5.2Gi       8.4Gi\nSwap:          4.0Gi          0B       4.0Gi',
    free: '               total        used        free      shared  buff/cache   available\nMem:            15Gi       6.3Gi       4.1Gi       412Mi       5.2Gi       8.4Gi\nSwap:          4.0Gi          0B       4.0Gi',
    'df -h': 'Filesystem      Size  Used Avail Use% Mounted on\n/dev/vda2       512G  190G  296G  40% /\n/dev/vda1       1.0G  6.1M  994M   1% /boot/efi\ntmpfs           7.9G     0  7.9G   0% /dev/shm',
    df: 'Filesystem      Size  Used Avail Use% Mounted on\n/dev/vda2       512G  190G  296G  40% /\n/dev/vda1       1.0G  6.1M  994M   1% /boot/efi\ntmpfs           7.9G     0  7.9G   0% /dev/shm',
    'lsb_release -a': `Distributor ID:\tCore OS\nDescription:\tCore OS ${config.coreOs.release}\nRelease:\t${config.coreOs.release}\nCodename:\tnoble`,
    lsbd: `Distributor ID:\tCore OS\nDescription:\tCore OS ${config.coreOs.release}\nRelease:\t${config.coreOs.release}\nCodename:\tnoble`,
    whoami: 'coreadmin',
    hostname: host,
    date: new Date().toString(),
    status:
      'core-os-build.service   active (exited)\nssh.service             active (running)\ndocker.service          active (running)\nufw.service             active (exited)\nfail2ban.service        active (running)',
  };

  if (cmd === 'clear') return { clear: true, output: '' };
  if (table[cmd] !== undefined) return { output: table[cmd] };
  return {
    output: `bash: ${cmd}: comando no disponible en el Modo Demo.\nEscribe "help" para ver los comandos permitidos.`,
    error: true,
  };
}

function runReal(command) {
  return new Promise((resolve) => {
    const spec = ALLOWLIST.get(command.trim());
    if (!spec) {
      resolve({
        output: `Comando no permitido. Escribe "help" para ver la lista blanca.`,
        error: true,
      });
      return;
    }
    execFile(spec.file, spec.args, { timeout: 5000, maxBuffer: 1024 * 256 }, (err, stdout, stderr) => {
      if (err) {
        resolve({ output: stderr || err.message, error: true });
      } else {
        resolve({ output: stdout || stderr || '(sin salida)' });
      }
    });
  });
}

export async function runCommand(command) {
  if (!command || typeof command !== 'string') {
    return { output: 'Uso: escribe un comando. Prueba con "help".', error: true };
  }
  const trimmed = command.trim();

  if (config.demoMode || !config.allowTerminal) {
    logger.debug(`terminal (demo): ${trimmed}`);
    return { ...simulated(trimmed), simulated: true };
  }

  logger.info(`terminal (real): ${trimmed}`);
  return { ...(await runReal(trimmed)), simulated: false };
}

export function availableCommands() {
  return [...ALLOWLIST.keys()].filter((k, i, arr) => arr.indexOf(k) === i);
}
