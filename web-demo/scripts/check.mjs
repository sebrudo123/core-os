#!/usr/bin/env node
/**
 * scripts/check.mjs — Comprobación de sintaxis de todos los .js del proyecto.
 * Se usa en CI (`npm run check`) sin necesidad de dependencias extra.
 */
import { readdirSync, statSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const dirs = ['src', 'api', 'public', 'scripts'];
const files = [];

function walk(dir) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }
  for (const entry of entries) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) walk(full);
    else if (entry.endsWith('.js') || entry.endsWith('.mjs')) files.push(full);
  }
}

for (const d of dirs) walk(join(root, d));
files.push(join(root, 'server.js'));

let failures = 0;
for (const file of files) {
  const rel = file.replace(`${root}/`, '');
  const res = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (res.status === 0) {
    console.log(`ok    ${rel}`);
  } else {
    failures += 1;
    console.error(`FALLA ${rel}\n${res.stderr}`);
  }
}

console.log(`\n${files.length} archivos comprobados, ${failures} con errores.`);
process.exit(failures === 0 ? 0 : 1);
