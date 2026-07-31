// Generates the PickPulse logo assets (app icon, splash, favicon, Android
// adaptive layers, and the in-app header mark) as PNGs.
//
// No image libraries are available in this project, so this encodes PNGs
// directly with zlib and antialiases by signed distance rather than by
// supersampling. Run it after changing the mark:
//   node scripts/generate-logo.mjs
import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const OUT = join(ROOT, 'assets', 'images');

// Brand colors, kept in sync with src/lib/theme.ts.
const BG = [0x0d, 0x0d, 0x17];
const ACCENT = [0xc6, 0xf4, 0x32];
const PURPLE = [0x80, 0x00, 0xff];
const WHITE = [0xff, 0xff, 0xff];

// The pulse waveform, in a normalized 0..1 box (y grows downward).
const PULSE = [
  [0.0, 0.55],
  [0.24, 0.55],
  [0.36, 0.8],
  [0.5, 0.14],
  [0.63, 0.66],
  [0.73, 0.55],
  [1.0, 0.55],
];

/** Distance from point p to segment ab. */
function distToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax;
  const dy = by - ay;
  const len2 = dx * dx + dy * dy;
  let t = len2 === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t < 0 ? 0 : t > 1 ? 1 : t;
  const cx = ax + t * dx;
  const cy = ay + t * dy;
  return Math.hypot(px - cx, py - cy);
}

/**
 * Renders the mark into an RGBA buffer.
 * The union of round-capped segments gives round joins for free.
 */
function render({ size, background, markColor, markScale, strokeScale, glow }) {
  const buf = Buffer.alloc(size * size * 4);

  // Place the mark box centered, occupying markScale of the canvas.
  const boxW = size * markScale;
  const boxH = boxW * 0.62;
  const boxX = (size - boxW) / 2;
  const boxY = (size - boxH) / 2;
  const pts = PULSE.map(([x, y]) => [boxX + x * boxW, boxY + y * boxH]);

  const halfW = size * strokeScale;
  const cx = size / 2;
  const cy = size * 0.46;
  const glowRadius = size * 0.55;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const px = x + 0.5;
      const py = y + 0.5;
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;

      if (background) {
        [r, g, b] = background;
        a = 255;
        if (glow) {
          // Soft radial purple bloom behind the mark, for depth.
          const d = Math.hypot(px - cx, py - cy) / glowRadius;
          const t = Math.max(0, 1 - d) ** 2 * 0.42;
          r = Math.round(r + (PURPLE[0] - r) * t);
          g = Math.round(g + (PURPLE[1] - g) * t);
          b = Math.round(b + (PURPLE[2] - b) * t);
        }
      }

      // Antialias on the distance field: full coverage inside, a one-pixel
      // ramp at the edge.
      let dist = Infinity;
      for (let i = 0; i < pts.length - 1; i++) {
        const d = distToSegment(px, py, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
        if (d < dist) dist = d;
      }
      const cov = Math.min(1, Math.max(0, halfW + 0.5 - dist));

      if (cov > 0) {
        const na = cov + (a / 255) * (1 - cov);
        r = Math.round((markColor[0] * cov + r * (a / 255) * (1 - cov)) / na);
        g = Math.round((markColor[1] * cov + g * (a / 255) * (1 - cov)) / na);
        b = Math.round((markColor[2] * cov + b * (a / 255) * (1 - cov)) / na);
        a = Math.round(na * 255);
      }

      const o = (y * size + x) * 4;
      buf[o] = r;
      buf[o + 1] = g;
      buf[o + 2] = b;
      buf[o + 3] = a;
    }
  }
  return buf;
}

/** Solid fill with the optional purple bloom, no mark. */
function renderBackground(size) {
  const buf = Buffer.alloc(size * size * 4);
  const cx = size / 2;
  const cy = size * 0.46;
  const glowRadius = size * 0.55;
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy) / glowRadius;
      const t = Math.max(0, 1 - d) ** 2 * 0.42;
      const o = (y * size + x) * 4;
      buf[o] = Math.round(BG[0] + (PURPLE[0] - BG[0]) * t);
      buf[o + 1] = Math.round(BG[1] + (PURPLE[1] - BG[1]) * t);
      buf[o + 2] = Math.round(BG[2] + (PURPLE[2] - BG[2]) * t);
      buf[o + 3] = 255;
    }
  }
  return buf;
}

// --- minimal PNG encoder -------------------------------------------------

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
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function encodePng(rgba, size) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // truecolor + alpha
  // Each scanline is prefixed with filter type 0 (None).
  const raw = Buffer.alloc((size * 4 + 1) * size);
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function write(name, rgba, size) {
  mkdirSync(OUT, { recursive: true });
  const file = join(OUT, name);
  writeFileSync(file, encodePng(rgba, size));
  console.log(`${name} (${size}x${size})`);
}

// --- outputs -------------------------------------------------------------

// App icon: full-bleed, the platforms apply their own corner mask.
write('icon.png', render({
  size: 1024, background: BG, markColor: ACCENT,
  markScale: 0.62, strokeScale: 0.042, glow: true,
}), 1024);

// Splash and header mark: transparent, no background plate.
write('splash-icon.png', render({
  size: 512, background: null, markColor: ACCENT,
  markScale: 0.82, strokeScale: 0.055,
}), 512);

write('logo-mark.png', render({
  size: 192, background: null, markColor: ACCENT,
  markScale: 0.9, strokeScale: 0.062,
}), 192);

write('favicon.png', render({
  size: 64, background: BG, markColor: ACCENT,
  markScale: 0.72, strokeScale: 0.05, glow: true,
}), 64);

// Android adaptive: the launcher masks to the centre ~66%, so the
// foreground mark is inset well inside that safe zone.
write('android-icon-background.png', renderBackground(1024), 1024);

write('android-icon-foreground.png', render({
  size: 1024, background: null, markColor: ACCENT,
  markScale: 0.46, strokeScale: 0.032,
}), 1024);

write('android-icon-monochrome.png', render({
  size: 1024, background: null, markColor: WHITE,
  markScale: 0.46, strokeScale: 0.032,
}), 1024);
