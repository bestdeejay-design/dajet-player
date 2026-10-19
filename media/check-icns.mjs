// Verifies that every entry in a .icns file is a real rendering of the icon —
// not noise, not blank, not a different picture from the rest, and not a plate
// that leaves a margin around itself.
//
// Unpacks the .icns by hand (no iconutil dependency — runs on Linux CI too),
// reads each PNG entry with sharp, and prints one line per entry:
//
//   type  size     plate      mark       edge   status
//   icp4  16x16    0.492      0.0078     1.00   ✅
//   icp5  32x32    0.510      0.0117     1.00   ✅
//   …
//
// An entry is "plate" when its pixels match the ground (#15181C) within a
// tolerance of 8 per channel; "mark" when they match the accent (#E8AE8C).
// Pixels that match neither (antialiasing, the alpha fringe) are uncounted.
//
// "edge" is the canon's other rule: the plate fills the canvas. It is the
// smallest share of plate-coloured pixels along the middle half of the entry's
// four outer rows and columns — 1.00 when the plate reaches every edge, 0.00
// when there is a clear margin around it. macOS 26 puts an icon with a margin
// inside a plate of its own, and the mark then reads as an icon inside an
// icon, so a margin is a defect and not a style.
//
// Exit codes:
//   0 — every entry has both plate and mark pixels, and a plate that fills it
//   1 — at least one entry is blank or noise (plate = 0 AND mark = 0), or has
//       a clear margin around the plate (edge < 0.5)
//
// The icon is drawn by Icon/icon.swift (the canon, in Swift) and lands in
// build/AppIcon.icns when build.sh runs; this checks that render, whichever
// file is pointed at.
//
// Usage:
//   node media/check-icns.mjs                   # checks build/AppIcon.icns
//   node media/check-icns.mjs path/to/icon.icns # checks that file

import sharp from 'sharp'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const GROUND = [21, 24, 28]       // #15181C
const ACCENT = [232, 174, 140]    // #E8AE8C
const TOLERANCE = 8               // per channel — catches antialias bleed

function matchColor(r, g, b, target) {
  return Math.abs(r - target[0]) <= TOLERANCE &&
         Math.abs(g - target[1]) <= TOLERANCE &&
         Math.abs(b - target[2]) <= TOLERANCE
}

/**
 * The middle half of each of the entry's four outer rows and columns. The
 * middle half, not the whole row: the plate's own corners are transparent by
 * design, and a corner is not a margin.
 */
function edgeSamples(info) {
  const xs = [Math.floor(info.width * 0.25), Math.ceil(info.width * 0.75)]
  const ys = [Math.floor(info.height * 0.25), Math.ceil(info.height * 0.75)]
  const top = [], bottom = [], left = [], right = []
  for (let x = xs[0]; x < xs[1]; x++) {
    top.push(x * 4)
    bottom.push(((info.height - 1) * info.width + x) * 4)
  }
  for (let y = ys[0]; y < ys[1]; y++) {
    left.push(y * info.width * 4)
    right.push((y * info.width + info.width - 1) * 4)
  }
  return { top, bottom, left, right }
}

/** The smallest share of plate-coloured pixels any edge of the entry has. */
function edgePlateFraction(data, info) {
  const sides = edgeSamples(info)
  const fraction = (indexes) =>
    indexes.filter((i) => data[i + 3] > 250 && matchColor(data[i], data[i + 1], data[i + 2], GROUND))
      .length / indexes.length
  return Math.min(
    fraction(sides.top),
    fraction(sides.bottom),
    fraction(sides.left),
    fraction(sides.right),
  )
}

async function analyzeEntry(buf) {
  const { data, info } = await sharp(buf)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true })
  const total = info.width * info.height
  let plate = 0, mark = 0
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i], g = data[i + 1], b = data[i + 2]
    if (matchColor(r, g, b, GROUND)) plate++
    if (matchColor(r, g, b, ACCENT)) mark++
  }
  return {
    width: info.width,
    height: info.height,
    total,
    plate,
    mark,
    plateFrac: plate / total,
    markFrac: mark / total,
    edgeFrac: edgePlateFraction(data, info),
  }
}

// ---------- .icns parser (PNG entries only, which is all this app writes) ----------

function parseIcns(buf) {
  const magic = buf.slice(0, 4).toString('ascii')
  if (magic !== 'icns') throw new Error(`Not an .icns file (magic: ${JSON.stringify(magic)})`)
  const fileLen = buf.readUInt32BE(4)
  if (fileLen > buf.length) throw new Error(`Truncated .icns: header says ${fileLen}, file is ${buf.length}`)

  const entries = []
  let offset = 8
  while (offset < fileLen) {
    if (offset + 8 > buf.length) break
    const type = buf.slice(offset, offset + 4).toString('ascii')
    const len = buf.readUInt32BE(offset + 4)
    if (len < 8 || offset + len > buf.length) break
    const data = buf.slice(offset + 8, offset + len)
    entries.push({ type, data })
    offset += len
  }
  return entries
}

// ---------- main ----------

const icnsPath = process.argv[2]
  ?? path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'build', 'AppIcon.icns')

if (!fs.existsSync(icnsPath)) {
  console.error(`check-icns: ${icnsPath} not found`)
  process.exit(2)
}

const buf = fs.readFileSync(icnsPath)
const entries = parseIcns(buf)

if (entries.length === 0) {
  console.error('check-icns: no entries found in .icns')
  process.exit(1)
}

let allOk = true
for (const { type, data } of entries) {
  try {
    const info = await analyzeEntry(data)
    const faults = []
    if (info.plate === 0 && info.mark === 0) faults.push('NOISE')
    if (info.edgeFrac < 0.5) faults.push('MARGIN: the plate does not fill the canvas')
    if (faults.length) allOk = false
    const status = faults.length ? `❌ ${faults.join(' · ')}` : '✅'
    console.log(
      `${type}  ${String(info.width).padStart(4)}x${String(info.height).padEnd(4)}` +
      `  plate=${info.plateFrac.toFixed(3)}` +
      `  mark=${info.markFrac.toFixed(4)}` +
      `  edge=${info.edgeFrac.toFixed(2)}` +
      `  ${status}`
    )
  } catch (e) {
    console.log(`${type}  (could not decode: ${e.message})`)
    allOk = false
  }
}

console.log(`\n${entries.length} entries, ${allOk ? 'all clean' : 'DEFECT DETECTED'}`)
process.exit(allOk ? 0 : 1)
