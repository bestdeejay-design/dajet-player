// The app's icon: the series' near-black squircle and one terracotta wave.
//
// The shape is the app's own mark (Sources/DajetPlayer/Design.swift, `Wave`),
// carried outside the window for the first time: an icon is the one place the
// mark stands without the app around it, so it is the mark and nothing else —
// no gradient, no second colour, no shadow of its own.
//
// The squircle is Apple's continuous corner, as a superellipse of n = 5, and
// it fills the canvas: the plate is 1024 on a 1024 canvas, with no clear
// margin around it. The classic grid — a body of 824, centred — is the one the
// wave was measured on (596 wide, 244 tall, a stroke of 74), and everything
// measured there grows by the same 1024/824 the plate grew by: the corner is
// 0.2253 x 1024 and the stroke is 92. That is the series' canon (the brand
// repository's palette.json), and the reason is macOS 26: the system puts an
// icon with clear margins inside a plate of its own, and the mark reads as an
// icon inside an icon. A plate that fills the canvas lands on the system's
// tile exactly, and there is no second frame to see.
//
//   node icon.mjs <assetsDir>

import sharp from 'sharp'
import fs from 'node:fs'
import path from 'node:path'

export const GROUND = '#15181C'
export const ACCENT = '#E8AE8C'

const CANVAS = 1024
const BODY = 824 // the grid the wave was measured on; the plate outgrew it
const PLATE = CANVAS // the plate fills the canvas — nothing clear around it
const GROWTH = PLATE / BODY // 1.2427: the mark grows with the plate
const CORNER = 0.2253 * PLATE
const STROKE = 92 // 74 x GROWTH, rounded: the canon's stroke at 1024

/** The continuous-cornered square, as a path of straight segments. */
export function squirclePathData(inset = (CANVAS - BODY) / 2, size = BODY, corner = 0.2253 * size, steps = 96, n = 5) {
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
 * The icon as SVG: the plate over the whole canvas, the wave grown with it.
 * One stroke for all sizes — the reviewer's note from PR #11 acceptance: no
 * optical sizing, no heavier line for small entries. The mark is the mark,
 * rendered once at full resolution and downscaled.
 */
export function iconSVG({ stroke = STROKE, background = GROUND, accent = ACCENT, label = 'Dajet Player' } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}" role="img" aria-label="${label}">
  <path d="${squirclePathData((CANVAS - PLATE) / 2, PLATE, CORNER)}" fill="${background}"/>
  <path d="${wavePathData(596 * GROWTH, 244 * GROWTH)}" fill="none" stroke="${accent}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"/>
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

/** The one render every raster comes from: the SVG at full resolution. */
export function renderMaster() {
  return sharp(Buffer.from(iconSVG()), { density: 72 })
    .resize(CANVAS, CANVAS)
    .png()
    .toBuffer()
}

export async function buildIcns() {
  // One render for every entry: full-resolution SVG, then downscale with a
  // quality filter. The small entries (16, 32) share the same raster as the
  // large ones — no separate stroke, no optical sizing, no chance of one
  // entry being a different picture from the rest.
  const master = await renderMaster()

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

/**
 * The same rasters the .icns carries, for the places a single file is wanted:
 * the 1024 render, and — with `magnify` — the smallest entry blown up without
 * smoothing, which is how the mark's legibility at 16 px is read by eye
 * rather than claimed.
 */
export async function iconPNG(size = CANVAS, { magnify = 1 } = {}) {
  const master = await renderMaster()
  const png = await (size === CANVAS
    ? sharp(master).png()
    : sharp(master).resize(size, size, { kernel: 'lanczos3' }).png()
  ).toBuffer()
  if (magnify === 1) return png
  return sharp(png)
    .resize(size * magnify, size * magnify, { kernel: 'nearest' })
    .png()
    .toBuffer()
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const out = process.argv[2] ?? path.resolve(import.meta.dirname, '..', 'assets')
  fs.mkdirSync(out, { recursive: true })
  const written = []
  const write = async (name, bytes) => {
    fs.writeFileSync(path.join(out, name), bytes)
    written.push(path.join(out, name))
  }
  await write('icon.svg', Buffer.from(iconSVG()))
  await write('icon-1024.png', await iconPNG(CANVAS))
  await write('AppIcon.icns', await buildIcns())
  // The 16 x 16 entry, 16 times larger and nearest-neighbour: the proof that
  // the mark still reads where there are sixteen pixels to read it in.
  await write('icon-16x16-enlarged.png', await iconPNG(16, { magnify: 16 }))
  console.log('wrote', written.join(', '))
}
