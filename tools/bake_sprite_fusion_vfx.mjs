import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';
import { stripTypeScriptTypes } from 'node:module';
import path from 'node:path';

const references = process.argv[2];
if (!references) throw new Error('Provide the directory of official Sprite Fusion VFX JSON references.');
const destination = process.argv[3] ? path.resolve(process.argv[3])
  : path.resolve(import.meta.dirname, '../assets/sprite_fusion/vfx');
await mkdir(path.join(destination, 'source'), { recursive: true });

const frameSize = 192;
const anchor = [96, 132];
const center = { x: anchor[0] * 2, y: anchor[1] * 2, seed: 3 };
const definitions = [
  { id: 'slash', source: 'slash', begin: 4 / 60, end: 0.6, frames: 32, options: {} },
  { id: 'impact', source: 'impact', begin: 0, end: 0.5, frames: 32, options: { angle: 0, size: 1.4 } },
  { id: 'muzzle', source: 'muzzle-flash', begin: 0, end: 0.55, frames: 32, options: { angle: 0, casing: false } },
  { id: 'dash', source: 'movement', begin: 8 / 60, end: 0.77, frames: 32, options: { kind: 'dash', distance: 75, time: 0.16 } },
  { id: 'blink', source: 'movement', begin: 0.3, end: 1.35, frames: 32, options: { kind: 'blink', to: center.x } },
  { id: 'fire', source: 'fire', begin: 0.22, end: 1.8, frames: 32,
    options: { box: [center.x - 18, center.y - 28, 36, 28], duration: 0.62, size: 0.8 } },
  { id: 'energy_charge', source: 'energy', begin: 0, end: 2.79, frames: 48, options: { kind: 'charge', charge: 2.8, colors: 'cyan' } },
  { id: 'gold_charge', source: 'energy', begin: 0, end: 2.79, frames: 48, options: { kind: 'charge', charge: 2.8, colors: 'gold' } },
  { id: 'energy', source: 'energy', begin: 0.3, end: 0.87, frames: 32, options: { kind: 'orb', radius: 15, colors: 'cyan' } },
  { id: 'gold_ray', source: 'energy', begin: 38 / 60, end: 0.94, frames: 8,
    options: { kind: 'beam', x: center.x - 100, to: [center.x + 100, center.y], charge: 0.55, hold: 0.08, width: 3.5, colors: 'gold' } },
  { id: 'arc_ray', source: 'energy', begin: 38 / 60, end: 0.94, frames: 8,
    options: { kind: 'beam', x: center.x - 100, to: [center.x + 100, center.y], charge: 0.55, hold: 0.08, width: 3.5, colors: 'cyan' } },
  { id: 'shield_charge', source: 'shield', begin: 0, end: 0.74, frames: 24, options: { radius: 29, hold: 0.8, hits: [] } },
  { id: 'shield', source: 'shield', begin: 0.75, end: 1.35, frames: 32, options: { radius: 29, hold: 0.8, hits: [] } },
  // The collapse glow has a 210px radius. A 192px canvas clips it into an opaque rectangle.
  { id: 'black_hole', source: 'black-hole', begin: 0.25, end: 1.75, frames: 40,
    canvasSize: 512, canvasAnchor: [256, 256], options: { radius: 18, life: 0.42 } },
  { id: 'holy_charge', source: 'holy-light', begin: 0, end: 0.415, frames: 24, options: { width: 11, hold: 0.25 } },
  { id: 'holy_light', source: 'holy-light', begin: 26 / 60, end: 1.19, frames: 40, options: { width: 11, hold: 0.25 } },
  { id: 'heal', source: 'heal', begin: 0, end: 2.4, frames: 48, options: { kind: 'heal', count: 10 } },
  { id: 'explosion', source: 'explosion', begin: 0, end: 1.2, frames: 40,
    canvasSize: 512, canvasAnchor: [256, 256],
    options: { size: 1.2, earth: 0.5, chunks: 7, fire: 0.7, scorch: 13, shockwave: 66 } },
];

const factories = new Map();
const sources = [];
for (const slug of [...new Set(definitions.map(definition => definition.source))]) {
  const result = JSON.parse(await readFile(path.join(references, `${slug}.json`), 'utf8')).vfx;
  const source = result.reference.split('```ts\n')[1]?.split('```')[0];
  if (!source) throw new Error(`Missing official TypeScript for ${slug}.`);
  await writeFile(path.join(destination, 'source', `${slug}.ts`), source);
  const javascript = stripTypeScriptTypes(source, { mode: 'transform' });
  const module = await import(`data:text/javascript;base64,${Buffer.from(javascript).toString('base64')}`);
  factories.set(slug, module.default);
  sources.push({ slug, page: result.page, download: result.download, file: `source/${slug}.ts` });
}

const manifest = { generator: 'Official Sprite Fusion MIT TypeScript effects', frame_size: frameSize, anchor,
  layers: ['back', 'front'], sources,
  bake: { tool: 'tools/bake_sprite_fusion_vfx.mjs',
    alpha: 'Source color plus encoded additive illumination, normal-alpha output',
    padded_radial_clips: ['black_hole', 'explosion'],
    note: 'Padded bake canvases retain the original source palette, time samples and pixel scale while avoiding clipped radial glows.' },
  clips: {} };
for (const definition of definitions) {
  const sampleSize = definition.canvasSize ?? frameSize;
  const sampleAnchor = definition.canvasAnchor ?? anchor;
  const columns = 8;
  const rows = Math.ceil(definition.frames / columns);
  const width = sampleSize * columns;
  const height = sampleSize * rows;
  const layers = { back: Buffer.alloc(width * height * 4), front: Buffer.alloc(width * height * 4) };
  const effect = factories.get(definition.source)({ ...center,
    x: sampleAnchor[0] * 2, y: sampleAnchor[1] * 2, ...definition.options });
  let elapsed = 0;
  for (let index = 0; index < definition.frames; index++) {
    const time = definition.begin + (definition.end - definition.begin) * index / (definition.frames - 1);
    while (elapsed + 1 / 60 <= time + 1e-7) {
      effect.update(1 / 60);
      elapsed += 1 / 60;
    }
    for (const layer of ['back', 'front']) {
      const color = new Uint32Array(sampleSize * sampleSize);
      const light = new Uint32Array(sampleSize * sampleSize);
      effect.draw({ w: sampleSize, h: sampleSize, ox: 0, oy: 0, color, light }, layer);
      for (let pixel = 0; pixel < color.length; pixel++) {
        const c = color[pixel];
        const l = light[pixel];
        const opacity = (c >>> 24) / 255;
        const glow = Math.max(l & 255, (l >>> 8) & 255, (l >>> 16) & 255) / 255;
        const alpha = opacity + glow * (1 - opacity);
        if (alpha <= 0) continue;
        const offset = ((Math.floor(index / columns) * sampleSize + Math.floor(pixel / sampleSize)) * width
          + (index % columns) * sampleSize + pixel % sampleSize) * 4;
        for (let channel = 0; channel < 3; channel++) {
          const foreground = (c >>> (channel * 8)) & 255;
          const illumination = (l >>> (channel * 8)) & 255;
          layers[layer][offset + channel] = Math.min(255, Math.round((foreground * opacity + illumination * (1 - opacity)) / alpha));
        }
        layers[layer][offset + 3] = Math.round(alpha * 255);
      }
    }
  }
  const crop = occupiedBounds(layers, width, definition.frames, columns, sampleSize);
  const emptyLayers = [];
  for (const layer of ['back', 'front']) {
    const compact = cropAtlas(layers[layer], width, definition.frames, columns, crop, sampleSize);
    if (compact.empty) emptyLayers.push(layer);
    await writeFile(path.join(destination, `${definition.id}_${layer}.png`),
      compact.empty ? png(1, 1, Buffer.alloc(4)) : png(crop.width * columns, crop.height * rows, compact.pixels));
  }
  manifest.clips[definition.id] = { source: definition.source, frames: definition.frames, columns,
    from_seconds: definition.begin, to_seconds: definition.end, options: definition.options,
    render_frame_size: [sampleSize, sampleSize], render_anchor: sampleAnchor,
    frame_size: [crop.width, crop.height], anchor: [sampleAnchor[0] - crop.x, sampleAnchor[1] - crop.y], empty_layers: emptyLayers,
    back: `${definition.id}_back.png`, front: `${definition.id}_front.png` };
  process.stdout.write(`${definition.id} ${definition.frames} frames ${crop.width}x${crop.height} ${2 - emptyLayers.length} layers\n`);
}
await writeFile(path.join(destination, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
await writeFile(path.join(destination, 'LICENSE.txt'), `MIT License\n\nCopyright (c) 2026 Hugo Duprez\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the "Software"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n`);

function png(width, height, rgba) {
  const scanlines = Buffer.alloc(height * (width * 4 + 1));
  for (let row = 0; row < height; row++) rgba.copy(scanlines, row * (width * 4 + 1) + 1, row * width * 4, (row + 1) * width * 4);
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header),
    chunk('IDAT', deflateSync(scanlines, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

function occupiedBounds(layers, width, count, columns, frameSize) {
  let left = frameSize;
  let top = frameSize;
  let right = 0;
  let bottom = 0;
  for (const pixels of Object.values(layers)) {
    for (let index = 0; index < count; index++) {
      const tileX = (index % columns) * frameSize;
      const tileY = Math.floor(index / columns) * frameSize;
      for (let y = 0; y < frameSize; y++) {
        for (let x = 0; x < frameSize; x++) {
          if (pixels[((tileY + y) * width + tileX + x) * 4 + 3] === 0) continue;
          left = Math.min(left, x);
          top = Math.min(top, y);
          right = Math.max(right, x + 1);
          bottom = Math.max(bottom, y + 1);
        }
      }
    }
  }
  left = Math.max(0, left - 1);
  top = Math.max(0, top - 1);
  right = Math.min(frameSize, right + 1);
  bottom = Math.min(frameSize, bottom + 1);
  return { x: left, y: top, width: right - left, height: bottom - top };
}

function cropAtlas(pixels, sourceWidth, count, columns, crop, frameSize) {
  const width = columns * crop.width;
  const packed = Buffer.alloc(width * Math.ceil(count / columns) * crop.height * 4);
  let empty = true;
  for (let index = 0; index < count; index++) {
    for (let row = 0; row < crop.height; row++) {
      const source = ((Math.floor(index / columns) * frameSize + crop.y + row) * sourceWidth
        + (index % columns) * frameSize + crop.x) * 4;
      const target = ((Math.floor(index / columns) * crop.height + row) * width + (index % columns) * crop.width) * 4;
      pixels.copy(packed, target, source, source + crop.width * 4);
      for (let x = 0; x < crop.width; x++) if (pixels[source + x * 4 + 3] > 0) empty = false;
    }
  }
  return { empty, pixels: packed };
}

function chunk(type, bytes) {
  const name = Buffer.from(type);
  const length = Buffer.alloc(4);
  length.writeUInt32BE(bytes.length);
  const crc = Buffer.alloc(4);
  let checksum = 0xffffffff;
  for (const byte of Buffer.concat([name, bytes])) {
    checksum ^= byte;
    for (let bit = 0; bit < 8; bit++) checksum = (checksum >>> 1) ^ (0xedb88320 & -(checksum & 1));
  }
  crc.writeUInt32BE((checksum ^ 0xffffffff) >>> 0);
  return Buffer.concat([length, name, bytes, crc]);
}
