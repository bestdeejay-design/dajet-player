// The app's icon: the series' near-black squircle and one terracotta wave.
//
// The shape is the app's own mark (Sources/DajetPlayer/Design.swift, `Wave`),
// carried outside the window for the first time: an icon is the one place the
// mark stands without the app around it, so it is the mark and nothing else —
// no gradient, no second colour, no shadow of its own.
//
// The squircle is Apple's continuous corner, as a superellipse of n = 5 over
// the 824-point body Big Sur's grid gives an icon on a 1024 canvas.
//
//   node icon.mjs <assetsDir>

import sharp from 'sharp'
import fs from 'node:fs'
import path from 'node:path'
import { deflateSync } from 'node:zlib'

export const GROUND = '#15181C'
export const ACCENT = '#E8AE8C'

const CANVAS = 1024
const BODY = 824
const CORNER = 0.2253 * BODY

/** The continuous-cornered square, as a path of straight segments. */
export function squirclePathData(inset = (CANVAS - BODY) / 2, size = BODY, corner = CORNER, steps = 96, n = 5) {
  const c = size / 2
  const a = c - corner
  const pts = []
  const arcs = [
    [c + a, c - a, -Math.PI / 2, 0],
    [c + a, c + a, 0, Math.PI / 2],
    [c - a, c + a, Math.PI / 2, Math.PI],
    [c - a, c - a, Math.PI, 1.5 * Math.PI],
  ]
  for (const [ccx, ccy, from, to] of arcs) {
    for (let i = 0; i <= steps; i++) {
      const t = from + (to - from) * (i / steps)
      const x = Math.sign(Math.cos(t)) * Math.abs(Math.cos(t)) ** (2 / n) * corner
      const y = Math.sign(Math.sin(t)) * Math.abs(Math.sin(t)) ** (2 / n) * corner
      pts.push([inset + ccx + x, inset + ccy + y])
    }
  }
  return 'M' + pts.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join('L') + 'Z'
}

/** One crest-to-crest sine across the icon, stroked with round ends. */
export function wavePathData(width = 596, height = 244, crests = 2, steps = 128) {
  const cx = CANVAS / 2
  const cy = CANVAS / 2
  const pts = []
  for (let i = 0; i <= steps; i++) {
    const along = i / steps
    pts.push([
      cx - width / 2 + width * along,
      cy - Math.sin(along * 2 * Math.PI * crests) * (height / 2),
    ])
  }
  return 'M' + pts.map(([x, y]) => `${x.toFixed(2)},${y.toFixed(2)}`).join('L')
}

/**
 * The icon as SVG. One stroke for all sizes — the reviewer's note from PR #11
 * acceptance: no optical sizing, no heavier line for small entries. The mark
 * is the mark, rendered once at full resolution and downscaled.
 */
export function iconSVG({ stroke = 74, background = GROUND, accent = ACCENT, label = 'Dajet Player' } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}" role="img" aria-label="${label}">
  <path d="${squirclePathData()}" fill="${background}"/>
  <path d="${wavePathData()}" fill="none" stroke="${accent}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
`
}

// ---------------------------------------------------------------- .icns

/**
 * A modern .icns: PNG entries only, which is what macOS 10.7 and later read
 * (the old raw-bitmap types are for systems this app does not run on). The
 * sizes are the grid Apple's own icon sets use, 16 to 512 at one and two
 * points per pixel.
 */
const ENTRIES = [
  { type: 'icp4', size: 16 },
  { type: 'icp5', size: 32 },
  { type: 'ic07', size: 128 },
  { type: 'ic08', size: 256 },
  { type: 'ic09', size: 512 },
  { type: 'ic10', size: 1024 },
  { type: 'ic11', size: 32 },
  { type: 'ic12', size: 64 },
  { type: 'ic13', size: 256 },
  { type: 'ic14', size: 512 },
]

function icnsChunk(type, data) {
  const head = Buffer.alloc(8)
  head.write(type, 0, 4, 'ascii')
  head.writeUInt32BE(data.length + 8, 4)
  return Buffer.concat([head, data])
}

export async function buildIcns() {
  // One render for every entry: full-resolution SVG, then downscale with a
  // quality filter. The small entries (16, 32) share the same raster as the
  // large ones — no separate stroke, no optical sizing, no chance of one
  // entry being a different picture from the rest.
  const master = await sharp(Buffer.from(iconSVG()), { density: 72 })
    .resize(CANVAS, CANVAS)
    .png()
    .toBuffer()

  const chunks = []
  for (const { type, size } of ENTRIES) {
    const png = await sharp(master)
      .resize(size, size, { kernel: 'lanczos3' })
      .png({ compressionLevel: 9 })
      .toBuffer()
    chunks.push(icnsChunk(type, png))
  }
  const body = Buffer.concat(chunks)
  const header = Buffer.alloc(8)
  header.write('icns', 0, 4, 'ascii')
  header.writeUInt32BE(body.length + 8, 4)
  return Buffer.concat([header, body])
}

/** The same PNGs the .icns carries, for the places a single file is wanted. */
export async function iconPNG(size) {
  const master = await sharp(Buffer.from(iconSVG()), { density: 72 })
    .resize(CANVAS, CANVAS)
    .png()
    .toBuffer()
  return sharp(master)
    .resize(size, size, { kernel: 'lanczos3' })
    .png()
    .toBuffer()
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const out = process.argv[2] ?? path.resolve(import.meta.dirname, '..', 'assets')
  fs.mkdirSync(out, { recursive: true })
  fs.writeFileSync(path.join(out, 'icon.svg'), iconSVG())
  fs.writeFileSync(path.join(out, 'AppIcon.icns'), await buildIcns())
  console.log('wrote', path.join(out, 'icon.svg'), 'and', path.join(out, 'AppIcon.icns'))
}
