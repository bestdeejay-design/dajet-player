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
 * The icon as SVG. `stroke` is the one number that changes between sizes: at
 * 16 points a 74/1024 line is under a pixel and a half and the mark goes grey,
 * so the small entries of the .icns are drawn a little heavier — the optical
 * sizing every icon set does, and the only difference between them.
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
  const chunks = []
  for (const { type, size } of ENTRIES) {
    // Optical sizing: the two smallest entries carry a heavier line, and
    // nothing else differs between them.
    const stroke = size <= 32 ? 96 : 74
    const svg = iconSVG({ stroke })
    const png = await sharp(Buffer.from(svg), { density: 96 / (CANVAS / size) })
      .resize(size, size)
      .png({ compressionLevel: 9 })
      .toBuffer()
    // sharp writes RGBA; an .icns entry is happier as RGB with an alpha
    // channel than as anything else, and macOS reads both.
    chunks.push(icnsChunk(type, png))
  }
  const body = Buffer.concat(chunks)
  const header = Buffer.alloc(8)
  header.write('icns', 0, 4, 'ascii')
  header.writeUInt32BE(body.length + 8, 4)
  return Buffer.concat([header, body])
}

/** The same PNGs the .icns carries, for the places a single file is wanted. */
export async function iconPNG(size, stroke = size <= 32 ? 96 : 74) {
  const svg = iconSVG({ stroke })
  return sharp(Buffer.from(svg), { density: 96 / (CANVAS / size) })
    .resize(size, size)
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
