import { mkdir, writeFile } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';
import path from 'node:path';

// Original Brass & Aether particle materials. These are painted, shaded pixel
// clusters, not vector outlines. The renderer supplies their emission physics.
const destination = process.argv[2] ? path.resolve(process.argv[2])
  : path.resolve(import.meta.dirname, '../assets/combat_particles');
await mkdir(destination, { recursive: true });
const S = 48;
const FRAMES = 12;
const materials = ['spark', 'ember', 'smoke', 'brass', 'aether', 'shield', 'heal', 'phase', 'crystal', 'slash', 'dust', 'arc'];
const rgba = Buffer.alloc(S * FRAMES * S * materials.length * 4);
const previews = Buffer.alloc(S * 3 * materials.length * S * 4);
const palette = colors => colors.map(c => [parseInt(c.slice(0, 2), 16), parseInt(c.slice(2, 4), 16), parseInt(c.slice(4, 6), 16)]);
const colors = {
  fire: palette(['762c26', 'b84227', 'e96c2c', 'ffad43', 'ffdc7c', 'fff3c7']),
  smoke: palette(['433b43', '584b50', '756367', '948083', 'b69f9b']),
  metal: palette(['4c3431', '805038', 'af7548', 'd9a866', 'f2d494', 'fff0bf']),
  aether: palette(['214565', '287c9c', '50b7c4', '93e3df', 'dcfff1', 'fffce3']),
  shield: palette(['244462', '376b87', '529bad', '8bd2d4', 'c4f2e6', 'f0fff0']),
  heal: palette(['29564c', '448761', '79ba77', 'addb92', 'def3b0', 'fff5cf']),
  phase: palette(['3b355b', '605086', '9475b8', 'c49ad7', 'eac6ed', 'fff3ff']),
  crystal: palette(['24425b', '397694', '67b4c4', 'a3e4e6', 'e4fff2', 'fffdf0']),
  dust: palette(['684435', '89583c', 'af794b', 'cc9863', 'e2b77b']),
};
const clamp = (v, low = 0, high = 1) => Math.min(high, Math.max(low, v));
const mix = (a, b, t) => a + (b - a) * t;
const noise = (x, y, seed = 0) => {
  const a = Math.sin(x * 12.9898 + y * 78.233 + seed * 31.725) * 43758.5453;
  return a - Math.floor(a);
};
function writePixel(buffer, width, x, y, c, alpha = 1) {
  if (x < 0 || y < 0 || x >= width || y >= buffer.length / (width * 4)) return;
  const i = (y * width + x) * 4;
  const source = clamp(alpha);
  const existing = buffer[i + 3] / 255;
  const combined = source + existing * (1 - source);
  if (combined <= 0) return;
  for (let k = 0; k < 3; k++) buffer[i + k] = Math.round((c[k] * source + buffer[i + k] * existing * (1 - source)) / combined);
  buffer[i + 3] = Math.round(combined * 255);
}
function paint(frame, painter) {
  for (let y = 3; y < S - 3; y++) for (let x = 3; x < S - 3; x++) {
    const pixel = painter(x - 24, y - 24, x, y);
    if (pixel) writePixel(frame, S, x, y, pixel[0], pixel[1]);
  }
}
function glow(frame, x, y, radius, color, opacity) {
  const cx = Math.round(x), cy = Math.round(y);
  for (let py = -radius; py <= radius; py++) for (let px = -radius; px <= radius; px++) {
    const distance = Math.hypot(px, py) / radius;
    if (distance > 1) continue;
    const clustered = noise(Math.floor(px / 2), Math.floor(py / 2), 18);
    const alpha = Math.round(Math.pow(1 - distance, 2.2) * opacity * (0.7 + clustered * 0.3) * 8) / 8;
    if (alpha > 0) writePixel(frame, S, cx + px, cy + py, color, alpha);
  }
}
function flecks(frame, p, family, seed, count = 7, power = 1) {
  for (let i = 0; i < count; i++) {
    const angle = noise(i, seed) * Math.PI * 2;
    const radius = (2 + noise(i + 3, seed) * 8) * (0.3 + p * 1.2);
    const x = Math.round(24 + Math.cos(angle) * radius);
    const y = Math.round(24 + Math.sin(angle) * radius - p * 2);
    const color = family[Math.min(family.length - 1, 2 + i % 3)];
    const alpha = Math.pow(1 - p, 0.7) * power;
    writePixel(frame, S, x, y, color, alpha);
    if (i % 3 === 0 && p < 0.7) writePixel(frame, S, x - 1, y, family[Math.min(family.length - 1, 4)], alpha * 0.7);
  }
}
function puff(frame, p, dust = false) {
  const family = dust ? colors.dust : colors.smoke;
  const opacity = Math.pow(1 - p, dust ? 0.72 : 0.85);
  const balls = Array.from({ length: 7 }, (_, i) => {
    const angle = i * 2.39996;
    const r = (2 + i * 0.75) * (0.4 + p * 0.65);
    return [Math.cos(angle) * r, Math.sin(angle) * r * (dust ? 0.38 : 0.8) - p * (dust ? 1 : 4),
      (4 + noise(i, 7) * 4) * (0.7 + p * 0.55)];
  });
  paint(frame, (x, y) => {
    let density = 0;
    for (const [bx, by, r] of balls) density = Math.max(density, 1 - Math.hypot(x - bx, (y - by) * (dust ? 1.8 : 1)) / r);
    const grain = noise(Math.floor((x + 32) / 2), Math.floor((y + 32) / 2), 9);
    density -= grain * 0.2;
    if (density <= 0.05) return;
    const shade = Math.floor(clamp(density * 0.45 + (-y + 7) / 28 + grain * 0.2) * (family.length - 1));
    return [family[shade], opacity * (0.32 + clamp(density * 2) * 0.5)];
  });
  if (dust) flecks(frame, p, colors.dust, 5, 6, 0.6);
}
function material(name, p) {
  const frame = Buffer.alloc(S * S * 4);
  const fade = Math.pow(1 - p, 0.58);
  if (name === 'smoke' || name === 'dust') { puff(frame, p, name === 'dust'); return frame; }
  if (name === 'spark') {
    glow(frame, 25, 24, 11, colors.fire[3], fade * 0.65);
    paint(frame, (x, y) => {
      const tail = clamp((x + 16) / 21);
      const center = Math.sin((x + p * 12) * 0.25) * (1 - tail) * 1.8;
      const radius = Math.abs(y - center);
      if (x < -16 || x > 6 || radius > (1.1 + tail * 2.7) || noise(x, y, 4) > tail * 0.7 + 0.35) return;
      const heat = clamp(1 - radius / 4 - (5 - x) / 35);
      return [colors.fire[Math.floor(heat * 5)], fade * (0.35 + tail * 0.65)];
    });
    flecks(frame, p, colors.fire, 2, 5);
  } else if (name === 'ember') {
    glow(frame, 24, 26, 13, colors.fire[2], fade * 0.45);
    paint(frame, (x, y) => {
      const height = 13 - y;
      const bend = Math.sin(height * 0.35 + p * 8) * (1 + height * 0.1);
      const width = Math.max(0, 7.8 - height * 0.27 + Math.sin(height * 0.7 + p * 11) * 1.5);
      const across = Math.abs(x - bend);
      if (y < -17 || y > 11 || across > width || noise(x, y, Math.floor(p * 5)) < 0.08) return;
      const heat = clamp((1 - across / Math.max(0.5, width)) * 0.65 + (y + 13) / 45);
      return [colors.fire[Math.floor(heat * 5)], fade * (0.62 + noise(x, y, 2) * 0.38)];
    });
    flecks(frame, p, colors.fire, 11, 6);
  } else if (name === 'brass') {
    const angle = p * Math.PI * 1.7 + 0.35;
    const turn = Math.cos(p * Math.PI * 1.4) * 0.65;
    paint(frame, (x, y) => {
      const u = x * Math.cos(angle) + y * Math.sin(angle);
      const v = -x * Math.sin(angle) + y * Math.cos(angle);
      const breadth = 3.8 + Math.abs(turn) * 3.5;
      if (u < -10 || u > 10 || Math.abs(v) > breadth * (1 - Math.abs(u) / 17)) return;
      const facet = v < 0 ? 3 : 1;
      const shine = Math.abs(v + breadth * 0.4) < 1.0 || u > 7 ? 2 : 0;
      return [colors.metal[Math.min(5, facet + shine + (noise(u, v, 4) > 0.75 ? 1 : 0))], fade];
    });
    if (p < 0.5) flecks(frame, p, colors.fire, 13, 4, 0.75);
  } else if (name === 'aether') {
    glow(frame, 24, 24, 15, colors.aether[2], fade * 0.6);
    paint(frame, (x, y) => {
      const radius = Math.hypot(x, y);
      const angle = Math.atan2(y, x);
      const surface = 7 + Math.sin(angle * 3 - p * 8) * 1.2 + Math.cos(angle * 5 + p * 6) * 0.7;
      if (radius > surface || noise(x, y, 3) < p * 0.09) return;
      const heat = clamp(1 - radius / 10 + (-x - y) / 30);
      return [colors.aether[Math.floor(heat * 5)], fade * (0.75 + heat * 0.25)];
    });
    flecks(frame, p, colors.aether, 21, 9);
  } else if (name === 'shield') {
    glow(frame, 24, 24, 15, colors.shield[2], fade * 0.4);
    paint(frame, (x, y) => {
      const bent = x + y * y / 25;
      const inside = Math.abs(bent) / 7 + Math.abs(y) / 13;
      if (inside > 1 || Math.abs(y) > 12) return;
      const crack = p > 0.55 && Math.abs(x + y * 0.3 - Math.sin(y * 1.8) * 1.2) < 0.75;
      if (crack) return;
      const sheen = Math.exp(-Math.pow((bent + 2 + Math.sin(p * 5) * 2) / 1.9, 2));
      const shade = Math.floor(clamp(0.14 + sheen * 0.6 + (1 - inside) * 0.25) * 5);
      return [colors.shield[shade], fade * (0.65 + sheen * 0.35)];
    });
    flecks(frame, p, colors.shield, 5, 5, 0.8);
  } else if (name === 'heal') {
    glow(frame, 24, 24, 14, colors.heal[2], fade * 0.5);
    paint(frame, (x, y) => {
      const rotated = p * 0.5;
      const u = x * Math.cos(rotated) + y * Math.sin(rotated);
      const v = -x * Math.sin(rotated) + y * Math.cos(rotated);
      const petal = Math.abs(u * 0.65 + v) / 10 + Math.abs(u - v * 0.65) / 4;
      if (petal > 1) return;
      const vein = Math.abs(u - v * 0.65) < 0.8;
      const shade = vein ? 4 : Math.min(4, Math.floor((1 - petal) * 3 + (u < 0 ? 1 : 0)));
      return [colors.heal[shade], fade];
    });
    flecks(frame, p, colors.heal, 12, 8);
  } else if (name === 'phase') {
    glow(frame, 24, 24, 14, colors.phase[2], fade * 0.45);
    paint(frame, (x, y) => {
      const curl = Math.sin((x + p * 14) * 0.23) * (3 + x / 12);
      const thickness = 1.3 + (x + 15) / 7;
      const across = Math.abs(y - curl);
      if (x < -16 || x > 9 || across > thickness || noise(Math.floor(x / 2), y, 14) < p * 0.35) return;
      const heat = clamp(1 - across / thickness + x / 28);
      return [colors.phase[Math.floor(heat * 5)], fade * (0.55 + heat * 0.45)];
    });
    flecks(frame, p, colors.phase, 7, 9);
  } else if (name === 'crystal') {
    const angle = p * 1.2 + 0.45;
    paint(frame, (x, y) => {
      const u = x * Math.cos(angle) + y * Math.sin(angle);
      const v = -x * Math.sin(angle) + y * Math.cos(angle);
      if (Math.abs(u) / 5 + Math.abs(v) / 12 > 1) return;
      const face = u < 0 ? (v < 0 ? 4 : 2) : (v < 0 ? 2 : 1);
      return [colors.crystal[Math.min(5, face + (Math.abs(u) < 0.75 ? 1 : 0))], fade];
    });
    flecks(frame, p, colors.crystal, 15, 6, 0.8);
  } else if (name === 'slash') {
    paint(frame, (x, y) => {
      const radius = Math.hypot(x + 7, y * 1.2);
      const angle = Math.atan2(y * 1.2, x + 7);
      const sweep = clamp((angle + 1.3) / 2.6);
      const width = Math.sin(sweep * Math.PI) * (3.5 + (1 - p) * 2);
      const distance = Math.abs(radius - 16);
      if (angle < -1.3 || angle > 1.3 || distance > width || noise(x, y, 18) < p * 0.2) return;
      const heat = clamp(1 - distance / Math.max(1, width));
      return [colors.fire[Math.min(5, 2 + Math.floor(heat * 3))], fade * (0.5 + heat * 0.5)];
    });
    flecks(frame, p, colors.fire, 16, 7, 0.7);
  } else if (name === 'arc') {
    glow(frame, 24, 24, 12, colors.aether[1], fade * 0.4);
    paint(frame, (x, y) => {
      if (x < -16 || x > 15) return;
      const step = Math.floor((x + 16) / 4);
      const kink = (noise(step, Math.floor(p * 8), 12) - 0.5) * 8;
      const distance = Math.abs(y - kink);
      const thickness = 1.1 + (1 - Math.abs(x) / 18) * 1.5;
      if (distance > thickness) return;
      return [colors.aether[distance < 0.8 ? 5 : distance < 1.5 ? 3 : 1], fade];
    });
    flecks(frame, p, colors.aether, 2, 6, 0.8);
  }
  return frame;
}

const manifest = { version: 1, generator: 'Brass & Aether original authored pixel particle materials',
  atlas: 'particles.png', frame_size: [S, S], columns: FRAMES, anchor: [24, 24],
  alpha: 'Straight normal-alpha RGBA', sampler: 'nearest', clips: {} };
for (let row = 0; row < materials.length; row++) {
  const name = materials[row];
  for (let f = 0; f < FRAMES; f++) {
    const frame = material(name, f / FRAMES);
    for (let y = 0; y < S; y++) {
      frame.copy(rgba, ((row * S + y) * (S * FRAMES) + f * S) * 4, y * S * 4, (y + 1) * S * 4);
      if ([0, 4, 8].includes(f)) frame.copy(previews, ((row * S + y) * (S * 3) + [0, 4, 8].indexOf(f) * S) * 4, y * S * 4, (y + 1) * S * 4);
    }
    // Every frame reserves a transparent border, including illuminated pixels.
    for (let x = 0; x < S; x++) for (const y of [0, S - 1]) if (frame[(y * S + x) * 4 + 3]) throw new Error(`${name}/${f} clips vertically`);
    for (let y = 0; y < S; y++) for (const x of [0, S - 1]) if (frame[(y * S + x) * 4 + 3]) throw new Error(`${name}/${f} clips horizontally`);
  }
  manifest.clips[name] = { row, frames: FRAMES, fps: 24, anchor: [24, 24], frame_size: [S, S],
    texture: 'particles.png', native_seconds: FRAMES / 24 };
}
await writeFile(path.join(destination, 'particles.png'), png(S * FRAMES, S * materials.length, rgba));
await writeFile(path.join(destination, 'materials-preview.png'), png(S * 3, S * materials.length, previews));
await writeFile(path.join(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
await writeFile(path.join(destination, 'README.txt'), 'Original Brass & Aether particle artwork. Rebuild with node tools/bake_combat_particle_textures.mjs.\nEach 48px texture cell has a centered anchor, crisp pixel clusters, internal shading and twelve lifecycle frames. The runtime owns all particle positions and tile timing. No paid generation or copied third-party art is used.\n');
console.log(`Baked ${materials.length} shaded materials, ${FRAMES} frames each, ${S * FRAMES}x${S * materials.length} atlas.`);

function png(width, height, bytes) {
  const rows = Buffer.alloc(height * (width * 4 + 1));
  for (let row = 0; row < height; row++) bytes.copy(rows, row * (width * 4 + 1) + 1, row * width * 4, (row + 1) * width * 4);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(rows, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function chunk(type, bytes) {
  const name = Buffer.from(type);
  const result = Buffer.alloc(bytes.length + 12);
  result.writeUInt32BE(bytes.length); name.copy(result, 4); bytes.copy(result, 8);
  let crc = 0xffffffff;
  for (const byte of Buffer.concat([name, bytes])) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  result.writeUInt32BE((crc ^ 0xffffffff) >>> 0, bytes.length + 8);
  return result;
}
