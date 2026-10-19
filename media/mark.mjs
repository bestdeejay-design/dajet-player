// The player's mark, as geometry — the squircle and the wave, and nothing drawn.
//
// The icon itself is not made here. It is drawn by Icon/icon.swift: the canon in
// Swift, generated at build time, no image asset kept in the repository. What
// lives in this file is only the geometry the generated pictures share, so the
// banners (svg.mjs) and the social cards (og.mjs) carry the same mark the app
// wears, from one source — without drawing an icon of their own.
//
// The numbers are the brand canon (the brand repository's palette.json): the
// series' near-black #15181C, one terracotta #E8AE8C, a plate of 1024 on a 1024
// canvas with no clear margin around it, the corner a superellipse n = 5 at
// 0.2253 x 1024, one wave stroked 92 with round ends. A plate that fills the
// canvas is what macOS 26 wants: the system puts an icon with clear margins
// inside a plate of its own, and the mark would read as an icon inside an icon.

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
 * The mark as SVG: the plate over the whole canvas, the wave grown with it.
 * One stroke for all sizes — no optical sizing, no heavier line for small
 * entries. Used by the banners and the cards; the icon's own SVG is written by
 * Icon/icon.swift.
 */
export function markSVG({ stroke = STROKE, background = GROUND, accent = ACCENT, label = 'Dajet Player' } = {}) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CANVAS}" height="${CANVAS}" viewBox="0 0 ${CANVAS} ${CANVAS}" role="img" aria-label="${label}">
  <path d="${squirclePathData((CANVAS - PLATE) / 2, PLATE, CORNER)}" fill="${background}"/>
  <path d="${wavePathData(596 * GROWTH, 244 * GROWTH)}" fill="none" stroke="${accent}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
`
}
