#!/usr/bin/env node
/**
 * generate-assets.mjs — Genera los recursos gráficos de Core OS (PNG reales)
 * sin dependencias externas: implementa un codificador PNG mínimo (zlib).
 *
 * Uso:  node generate-assets.mjs
 * Salida:  ../logo/core-os.png
 *          ../grub/background.png, ../grub/logo.png
 *          ../plymouth/logo.png
 */
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const BRAND = join(HERE, '..');

/* ---------------------------------- PNG ---------------------------------- */
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])), 0);
  return Buffer.concat([len, t, data, crc]);
}

/** rgbaFn(x,y) -> [r,g,b,a] (0-255) */
function png(width, height, rgbaFn) {
  const stride = width * 4 + 1;
  const raw = Buffer.alloc(stride * height);
  let o = 0;
  for (let y = 0; y < height; y++) {
    raw[o++] = 0; // filtro None
    for (let x = 0; x < width; x++) {
      const px = rgbaFn(x, y);
      raw[o++] = px[0]; raw[o++] = px[1]; raw[o++] = px[2]; raw[o++] = px[3];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 6;  // color type RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* --------------------------------- utils --------------------------------- */
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
const mix = (a, b, t) => a + (b - a) * t;
const lerp3 = (c1, c2, t) => [mix(c1[0], c2[0], t), mix(c1[1], c2[1], t), mix(c1[2], c2[2], t)];
const BG = [11, 18, 32];
const BG2 = [19, 32, 59];
const ACCENT = [56, 189, 248];
const ACCENT2 = [37, 99, 235];

function save(rel, buf) {
  const out = join(BRAND, rel);
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, buf);
  console.log(`generado ${rel} (${(buf.length / 1024).toFixed(1)} KiB)`);
}

/* ------------------------------- 1. logo 512 ------------------------------ */
function makeLogo(size, transparent) {
  const r = size * 0.46;
  const cx = size / 2;
  const cy = size / 2;
  const ringOuter = size * 0.30;
  const ringWidth = size * 0.055;
  const dot = size * 0.13;
  const radius = size * 0.22; // esquinas redondeadas
  return png(size, size, (x, y) => {
    const dx = x - cx;
    const dy = y - cy;
    const d = Math.hypot(dx, dy);

    // fondo con esquinas redondeadas
    let bgA = 255;
    if (transparent) {
      bgA = 0;
    } else {
      const qx = Math.abs(dx) - (size / 2 - radius - 2);
      const qy = Math.abs(dy) - (size / 2 - radius - 2);
      const qd = Math.hypot(Math.max(qx, 0), Math.max(qy, 0));
      const edge = qd + radius - (size / 2 - 2);
      bgA = clamp(255 * (1 - Math.max(0, edge)));
    }

    // gradiente del anillo
    const grad = clamp((x / size + y / size) / 2 * 255);
    const ring = lerp3(ACCENT2, ACCENT, grad / 255);

    let r0 = BG[0], g0 = BG[1], b0 = BG[2];

    if (d <= radius && !transparent) {
      const t = (x / size + y / size) / 2;
      const c = lerp3(BG, BG2, t);
      r0 = c[0]; g0 = c[1]; b0 = c[2];
    }

    let a = bgA;

    // anillo
    const ringMask = 1 - Math.min(1, Math.abs(d - ringOuter) / ringWidth);
    if (ringMask > 0) {
      const t = clamp(255 * ringMask) / 255;
      r0 = mix(r0, ring[0], t);
      g0 = mix(g0, ring[1], t);
      b0 = mix(b0, ring[2], t);
      a = Math.max(a, clamp(255 * ringMask * (transparent ? 1 : 1)));
    }
    // punto central
    const dotMask = 1 - Math.min(1, Math.max(0, (d - dot) / (size * 0.01) + 1));
    if (d <= dot) {
      const t = (x / size + y / size) / 2;
      const c = lerp3(ACCENT2, ACCENT, t);
      r0 = c[0]; g0 = c[1]; b0 = c[2];
      a = Math.max(a, 255);
    }
    return [clamp(r0), clamp(g0), clamp(b0), clamp(a)];
  });
}

/* --------------------------- 2. fondo GRUB 16:9 --------------------------- */
function makeGrubBackground(w, h) {
  const glowX = w * 0.72;
  const glowY = h * 0.28;
  return png(w, h, (x, y) => {
    const t = (x / w + y / h) / 2;
    let c = lerp3(BG, BG2, t);
    // resplandor radial
    const d = Math.hypot(x - glowX, y - glowY) / (w * 0.6);
    const glow = Math.max(0, 1 - d) ** 2 * 0.35;
    c = [mix(c[0], ACCENT[0], glow), mix(c[1], ACCENT[1], glow), mix(c[2], ACCENT[2], glow)];
    // viñeta
    const vx = (x - w / 2) / (w / 2);
    const vy = (y - h / 2) / (h / 2);
    const vig = 1 - 0.25 * Math.min(1, Math.hypot(vx, vy));
    return [clamp(c[0] * vig), clamp(c[1] * vig), clamp(c[2] * vig), 255];
  });
}

const logo512 = makeLogo(512, false);
save('logo/core-os.png', logo512);
save('grub/logo.png', makeLogo(96, true));
save('grub/background.png', makeGrubBackground(1920, 1080));
// Pantalla del menú de arranque BIOS (syslinux/vesamenu): resolución moderada
// para que cualquier firmware pueda mostrarla.
save('grub/splash-syslinux.png', makeGrubBackground(1024, 768));

console.log('Recursos generados correctamente.');
