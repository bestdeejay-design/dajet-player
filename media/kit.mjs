// The drawing kit the media of dajet-player are made with.
//
// Everything here is derived from the app itself: the colours are the pairs in
// Sources/DajetPlayer/Design.swift, the distances are its Metrics, and the
// marks (the wave) are its shapes. Nothing in this file invents a look — it
// re-draws the one the app has, at 2x, so that a screenshot of a Mac that is
// not here can be an honest picture of what the app draws.
//
// Written for @napi-rs/canvas, which has no Path2D: the little SVG-path
// interpreter below is what reads the symbol outlines.

import { createCanvas, GlobalFonts, Image } from '@napi-rs/canvas'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

// ---------------------------------------------------------------- fonts

// The faces in media/fonts, beside this file rather than anywhere absolute:
// the generators are meant to run from a checkout, wherever it is.
const FONT_DIR = dirname(fileURLToPath(import.meta.url)) + '/fonts'
for (const w of [400, 500, 600, 700]) {
  GlobalFonts.registerFromPath(`${FONT_DIR}/Inter-${w}.ttf`, `Inter ${w}`)
}
// SF Pro is Apple's and is not here; Inter is what stands in for it, and the
// numbers the app lays out with are used as they are.

export const SF = (weight) => `Inter ${weight ?? 400}`

// ---------------------------------------------------------------- canvas

export function makeCanvas(width, height, scale = 2) {
  const canvas = createCanvas(Math.round(width * scale), Math.round(height * scale))
  const ctx = canvas.getContext('2d')
  ctx.scale(scale, scale)
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = 'high'
  return { canvas, ctx }
}

export async function writePNG(canvas, path) {
  const buf = await canvas.encode('png')
  const fs = await import('node:fs')
  fs.mkdirSync(path.split('/').slice(0, -1).join('/'), { recursive: true })
  fs.writeFileSync(path, buf)
  return buf
}

export async function loadImage(path) {
  const fs = await import('node:fs')
  const img = new Image()
  img.src = fs.readFileSync(path)
  return img
}

// ---------------------------------------------------------------- colour

/** "#RRGGBB" from three 0..1 components. */
export const srgb = (r, g, b) =>
  '#' + [r, g, b].map((v) => Math.round(v * 255).toString(16).padStart(2, '0')).join('')

export const rgba = (r, g, b, a) =>
  `rgba(${Math.round(r * 255)},${Math.round(g * 255)},${Math.round(b * 255)},${a})`

export const alpha = (hex, a) => {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`
}

/**
 * The palette, one member per `Palette.Pair` in Design.swift, each with the
 * light and the dark value the app resolves against the window's appearance.
 * `veil` members are laid over something rather than being a surface: they are
 * carried as rgba so that whatever is under them still shows through.
 */
export const Palette = {
  ground: { light: srgb(0.957, 0.945, 0.910), dark: srgb(0.039, 0.043, 0.051) },
  ink: { light: srgb(0.086, 0.094, 0.110), dark: srgb(0.957, 0.945, 0.910) },
  muted: { light: srgb(0.420, 0.427, 0.443), dark: srgb(0.655, 0.647, 0.624) },
  faint: { light: srgb(0.600, 0.608, 0.624), dark: srgb(0.451, 0.451, 0.443) },
  hairline: { light: 'rgba(0,0,0,0.10)', dark: 'rgba(255,255,255,0.09)' },
  hover: { light: 'rgba(0,0,0,0.045)', dark: 'rgba(255,255,255,0.055)' },
  wash: { light: 'rgba(193,84,43,0.10)', dark: 'rgba(232,174,140,0.14)' },
  accent: { light: srgb(0.757, 0.329, 0.169), dark: srgb(0.910, 0.682, 0.549) },
  pane: { light: 'rgba(255,255,255,0.34)', dark: 'rgba(255,255,255,0.045)' },
  side: { light: 'rgba(245,247,250,0.92)', dark: 'rgba(19,20,23,0.94)' },
  onAccent: { light: '#FFFFFF', dark: srgb(0.055, 0.059, 0.067) },
  // The series' colours, for the brand media that are not the window.
  seriesGround: '#15181C',
  seriesSurface: '#1E2227',
  seriesText: '#F4F1E8',
  seriesSecondary: '#A8A29E',
  seriesAccent: '#E8AE8C',
}

export const ink = (name, theme) => Palette[name][theme]

/** The light glass wash, as Window.swift wears it (P-10R). */
export const Glass = {
  lift: 'rgba(255,255,255,0.025)',
  sheen: 'rgba(255,255,255,0.07)',
  foot: 'rgba(0,0,0,0.022)',
}

// ---------------------------------------------------------------- shapes

export function roundRect(ctx, x, y, w, h, r) {
  const rr = Math.max(0, Math.min(r, Math.min(w, h) / 2))
  ctx.beginPath()
  ctx.moveTo(x + rr, y)
  ctx.lineTo(x + w - rr, y)
  ctx.arcTo(x + w, y, x + w, y + rr, rr)
  ctx.lineTo(x + w, y + h - rr)
  ctx.arcTo(x + w, y + h, x + w - rr, y + h, rr)
  ctx.lineTo(x + rr, y + h)
  ctx.arcTo(x, y + h, x, y + h - rr, rr)
  ctx.lineTo(x, y + rr)
  ctx.arcTo(x, y, x + rr, y, rr)
  ctx.closePath()
}

export function fillRect(ctx, colour, x, y, w, h, r = 0) {
  ctx.fillStyle = colour
  if (r > 0) { roundRect(ctx, x, y, w, h, r); ctx.fill() } else { ctx.fillRect(x, y, w, h) }
}

export function strokeRect(ctx, colour, x, y, w, h, r = 0, width = 1) {
  ctx.strokeStyle = colour
  ctx.lineWidth = width
  if (r > 0) { roundRect(ctx, x + width / 2, y + width / 2, w - width, h - width, r); ctx.stroke() }
  else ctx.strokeRect(x + width / 2, y + width / 2, w - width, h - width)
}

/** A circle as a path of its own (there is no arc-based Path2D here). */
export function circle(ctx, cx, cy, r) {
  ctx.beginPath()
  ctx.arc(cx, cy, r, 0, Math.PI * 2)
}

/**
 * A rounded rectangle with Apple's continuous corners — the shape SwiftUI
 * draws for `.continuous`. A superellipse of n = 5 is what stands in for it.
 */
export function squirclePath(ctx, x, y, w, h, r, steps = 24, n = 5) {
  const cx = x + w / 2
  const cy = y + h / 2
  const a = w / 2 - r
  const b = h / 2 - r
  ctx.beginPath()
  const corner = (ccx, ccy, from, to) => {
    for (let i = 0; i <= steps; i++) {
      const t = from + (to - from) * (i / steps)
      const px = Math.sign(Math.cos(t)) * Math.abs(Math.cos(t)) ** (2 / n) * r
      const py = Math.sign(Math.sin(t)) * Math.abs(Math.sin(t)) ** (2 / n) * r
      const X = ccx + px
      const Y = ccy + py
      if (i === 0 && from === -Math.PI / 2) ctx.moveTo(X, Y)
      else ctx.lineTo(X, Y)
    }
  }
  corner(cx + a, cy - b, -Math.PI / 2, 0)
  corner(cx + a, cy + b, 0, Math.PI / 2)
  corner(cx - a, cy + b, Math.PI / 2, Math.PI)
  corner(cx - a, cy - b, Math.PI, 1.5 * Math.PI)
  ctx.closePath()
}

/** The app's Wave (Design.swift): one sine, stroked. */
export function wavePath(ctx, x, y, w, h, crests = 2, steps = 96) {
  ctx.beginPath()
  for (let i = 0; i <= steps; i++) {
    const along = i / steps
    const px = x + w * along
    const py = y + h / 2 - Math.sin(along * 2 * Math.PI * crests) * (h / 2)
    if (i === 0) ctx.moveTo(px, py)
    else ctx.lineTo(px, py)
  }
}

// ---------------------------------------------------------------- text

const CAP = 0.727   // Inter's cap height, as a share of the size
const XH = 0.727    // used for optical centring of a line

/**
 * One line of text. `y` is the *centre* of the line's cap height unless
 * `baseline` is set, which is what a layout thinks in.
 */
export function text(ctx, str, x, y, opts = {}) {
  const { size = 13, weight = 400, colour = '#000', align = 'left', tracking = 0, baseline = false, maxWidth } = opts
  ctx.save()
  ctx.font = `${size}px "${SF(weight)}"`
  if ('letterSpacing' in ctx) ctx.letterSpacing = `${tracking}px`
  ctx.fillStyle = colour
  ctx.textAlign = align === 'center' ? 'center' : align === 'right' ? 'right' : 'left'
  ctx.textBaseline = 'alphabetic'
  const yy = baseline ? y : y + (size * CAP) / 2
  if (maxWidth) ctx.fillText(str, x, yy, maxWidth)
  else ctx.fillText(str, x, yy)
  ctx.restore()
}

export function width(ctx, str, size = 13, weight = 400, tracking = 0) {
  ctx.save()
  ctx.font = `${size}px "${SF(weight)}"`
  if ('letterSpacing' in ctx) ctx.letterSpacing = `${tracking}px`
  const w = ctx.measureText(str).width
  ctx.restore()
  return w
}

/** Truncation in the middle, the way the app's rows do it. */
export function clipText(ctx, str, x, y, maxWidth, opts = {}) {
  const { size = 13, weight = 400, colour = '#000', align = 'left', tracking = 0 } = opts
  let s = str
  if (width(ctx, s, size, weight, tracking) <= maxWidth) {
    text(ctx, s, x, y, { ...opts, size, weight, colour, align, tracking })
    return
  }
  let cut = s.length
  while (cut > 4 && width(ctx, s.slice(0, cut) + '…', size, weight, tracking) > maxWidth) cut--
  s = s.slice(0, cut).trimEnd() + '…'
  text(ctx, s, x, y, { ...opts, size, weight, colour, align, tracking })
}

// ---------------------------------------------------------------- symbols

/**
 * A very small SVG-path reader: absolute and relative commands, lines, cubics,
 * quadratics, and the close. Enough for the symbol outlines below and nothing
 * more — this is not a renderer, it is a way of writing a glyph down.
 */
export function path(ctx, d) {
  const tokens = d.match(/[MmLlHhVvCcQqZz]|-?\d*\.?\d+(?:e-?\d+)?/g) ?? []
  let i = 0
  let cx = 0
  let cy = 0
  let startX = 0
  let startY = 0
  let cmd = 'M'
  const num = () => parseFloat(tokens[i++])
  ctx.beginPath()
  while (i < tokens.length) {
    if (/[MmLlHhVvCcQqZz]/.test(tokens[i])) cmd = tokens[i++]
    const rel = cmd === cmd.toLowerCase()
    switch (cmd.toUpperCase()) {
      case 'M': {
        const x = num(); const y = num()
        cx = rel ? cx + x : x
        cy = rel ? cy + y : y
        ctx.moveTo(cx, cy)
        startX = cx; startY = cy
        break
      }
      case 'L': {
        const x = num(); const y = num()
        cx = rel ? cx + x : x
        cy = rel ? cy + y : y
        ctx.lineTo(cx, cy)
        break
      }
      case 'H': {
        const x = num()
        cx = rel ? cx + x : x
        ctx.lineTo(cx, cy)
        break
      }
      case 'V': {
        const y = num()
        cy = rel ? cy + y : y
        ctx.lineTo(cx, cy)
        break
      }
      case 'C': {
        const a = num(); const b = num(); const c = num(); const dd = num(); const e = num(); const f = num()
        const x1 = rel ? cx + a : a; const y1 = rel ? cy + b : b
        const x2 = rel ? cx + c : c; const y2 = rel ? cy + dd : dd
        cx = rel ? cx + e : e; cy = rel ? cy + f : f
        ctx.bezierCurveTo(x1, y1, x2, y2, cx, cy)
        break
      }
      case 'Q': {
        const a = num(); const b = num(); const c = num(); const dd = num()
        const x1 = rel ? cx + a : a; const y1 = rel ? cy + b : b
        cx = rel ? cx + c : c; cy = rel ? cy + dd : dd
        ctx.quadraticCurveTo(x1, y1, cx, cy)
        break
      }
      case 'Z': {
        ctx.closePath()
        cx = startX; cy = startY
        break
      }
      default:
        i++
    }
  }
}

/**
 * One glyph, drawn in a 20 x 20 box scaled to `size` and centred on (x, y).
 * The outlines are hand-written after the system's own symbols, because the
 * app wears SF Symbols and there is nothing else on this machine that can
 * draw them: a screenshot with substituted pictures would be a picture of
 * another app.
 */
export function symbol(ctx, name, x, y, size, colour, weight = 1.6) {
  if (name.endsWith('.badge.plus')) {
    // The badge the system draws on a folder is a filled disc that *knocks a
    // hole* in the folder under it and carries the plus in the window's own
    // colour. On glass the hole cannot be a colour — whatever is behind the
    // window has to come through it — so the whole glyph is drawn on a canvas
    // of its own and the hole is punched out of that: the window's ground is
    // then what shows through it, which is what the system's own badge does.
    const box = size * 2
    const { canvas: off, ctx: octx } = makeCanvas(box, box, 2)
    const c = size / 2 + size / 2
    const s2 = size / 20
    octx.save()
    octx.translate(size / 2, size / 2)
    octx.scale(s2, s2)
    octx.strokeStyle = colour
    octx.fillStyle = colour
    octx.lineCap = 'round'
    octx.lineJoin = 'round'
    octx.lineWidth = weight / s2
    SYMBOLS['folder'](octx)
    octx.restore()
    // the hole, and the accent disc that sits in it
    octx.save()
    octx.globalCompositeOperation = 'destination-out'
    octx.beginPath()
    octx.arc(size / 2 + 15.2 * s2, size / 2 + 15.2 * s2, 4.6 * s2, 0, Math.PI * 2)
    octx.fillStyle = '#000'
    octx.fill()
    octx.restore()
    octx.beginPath()
    octx.arc(size / 2 + 15.2 * s2, size / 2 + 15.2 * s2, 4.0 * s2, 0, Math.PI * 2)
    octx.fillStyle = colour
    octx.fill()
    // the plus, knocked out of the disc
    octx.save()
    octx.globalCompositeOperation = 'destination-out'
    octx.strokeStyle = '#000'
    octx.lineWidth = 1.35 * s2
    octx.lineCap = 'round'
    path(octx, `M${size / 2 + 15.2 * s2},${size / 2 + (15.2 - 1.9) * s2} L${size / 2 + 15.2 * s2},${size / 2 + (15.2 + 1.9) * s2} M${size / 2 + (15.2 - 1.9) * s2},${size / 2 + 15.2 * s2} L${size / 2 + (15.2 + 1.9) * s2},${size / 2 + 15.2 * s2}`)
    octx.stroke()
    octx.restore()
    ctx.drawImage(off, x - box / 2, y - box / 2, box, box)
    return
  }
  draw(ctx, name, x, y, size, colour, weight)
}

/**
 * The glyph itself, without the badge's own canvas: `cx`, `cy` are the centre
 * it is drawn about, and the pair at the end is the box it is scaled into.
 */
function draw(ctx, name, x, y, size, colour, weight = 1.6, boxX = null, boxY = null) {
  const s = size / 20
  ctx.save()
  if (boxX === null) ctx.translate(x - size / 2, y - size / 2)
  else ctx.translate(boxX, boxY)
  ctx.scale(s, s)
  ctx.strokeStyle = colour
  ctx.fillStyle = colour
  ctx.lineWidth = weight
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  const g = SYMBOLS[name]
  if (!g) throw new Error(`no symbol: ${name}`)
  g(ctx)
  ctx.restore()
}

/** The same, but filled: the app uses the filled variants for the transport. */
export function symbolFilled(ctx, name, x, y, size, colour) {
  const s = size / 20
  ctx.save()
  ctx.translate(x - size / 2, y - size / 2)
  ctx.scale(s, s)
  ctx.fillStyle = colour
  const g = SYMBOLS[name]
  if (!g) throw new Error(`no symbol: ${name}`)
  g(ctx)
  ctx.restore()
}

// The outlines. Each is the shape a 20 x 20 box would hold, drawn the way the
// system draws it: line weight 1.6 at this size, round caps and joins.
const SYMBOLS = {
  // A window with its leading column: the toolbar's toggle.
  'sidebar.leading': (ctx) => {
    roundRect(ctx, 2, 3.4, 16, 13.2, 3.6)
    ctx.lineWidth = 1.5
    ctx.stroke()
    path(ctx, 'M7.4,3.4 L7.4,16.6')
    ctx.lineWidth = 1.5
    ctx.stroke()
    path(ctx, 'M4.2,5.2 C3.2,5.2 2.6,5.8 2.6,6.4 L2.6,13.6 C2.6,14.2 3.2,14.8 4.2,14.8 L7.4,14.8 L7.4,5.2 Z')
    ctx.fill()
  },
  'sidebar.leading.outline': (ctx) => {
    roundRect(ctx, 2, 3.4, 16, 13.2, 3.6)
    ctx.lineWidth = 1.5
    ctx.stroke()
    path(ctx, 'M7.4,5.2 L4.6,5.2 M7.4,3.4 L7.4,16.6')
    ctx.lineWidth = 1.5
    ctx.stroke()
  },
  // A folder with a plus at its foot: add a folder of music.
  folder: (ctx) => {
    path(ctx, 'M2.4,6.4 C2.4,5.3 3.2,4.6 4.3,4.6 L7.1,4.6 C7.7,4.6 8.2,4.9 8.5,5.3 L9.2,6.4 L15.7,6.4 C16.8,6.4 17.6,7.2 17.6,8.3 L17.6,14.2 C17.6,15.3 16.8,16 15.7,16 L4.3,16 C3.2,16 2.4,15.3 2.4,14.2 Z')
    ctx.lineWidth = 1.5
    ctx.stroke()
  },
  'folder.badge.plus': (ctx) => SYMBOLS.folder(ctx),
  'sun.max': (ctx) => {
    circle(ctx, 10, 10, 3.6)
    ctx.lineWidth = 1.6
    ctx.stroke()
    for (let k = 0; k < 8; k++) {
      const a = (k * Math.PI) / 4
      path(ctx, `M${10 + Math.cos(a) * 6.2},${10 + Math.sin(a) * 6.2} L${10 + Math.cos(a) * 8.1},${10 + Math.sin(a) * 8.1}`)
      ctx.stroke()
    }
  },
  moon: (ctx) => {
    ctx.lineWidth = 1.6
    path(ctx, 'M12.4,3.2 C8.4,4.4 5.6,8.1 5.6,12.4 C5.6,16.7 8.4,20.4 12.4,21.6 L12.4,3.2 Z')
    path(ctx, 'M12.4,2.6 A9.4,9.4 0 0 0 12.4,17.4 A7.6,7.6 0 0 1 12.4,2.6 Z')
    ctx.stroke()
  },
  'circle.lefthalf.filled': (ctx) => {
    circle(ctx, 10, 10, 7.2)
    ctx.lineWidth = 1.5
    ctx.stroke()
    path(ctx, 'M10,2.8 A7.2,7.2 0 0 0 10,17.2 Z')
    ctx.fill()
  },
  'play.fill': (ctx) => {
    path(ctx, 'M5.4,2.9 C5.4,1.9 6.5,1.3 7.4,1.8 L17.3,8.5 C18.1,9 18.1,10.2 17.3,10.7 L7.4,17.4 C6.5,17.9 5.4,17.3 5.4,16.3 Z')
    ctx.fill()
  },
  'pause.fill': (ctx) => {
    roundRect(ctx, 4.2, 2.6, 4.4, 14.8, 1.5)
    ctx.fill()
    roundRect(ctx, 11.4, 2.6, 4.4, 14.8, 1.5)
    ctx.fill()
  },
  'backward.fill': (ctx) => {
    path(ctx, 'M10.6,5.2 L2.9,9.4 C2.2,9.8 2.2,10.8 2.9,11.2 L10.6,15.4 Z')
    ctx.fill()
    path(ctx, 'M18.2,5.2 L10.5,9.4 C9.8,9.8 9.8,10.8 10.5,11.2 L18.2,15.4 Z')
    ctx.fill()
  },
  'forward.fill': (ctx) => {
    path(ctx, 'M9.4,5.2 L17.1,9.4 C17.8,9.8 17.8,10.8 17.1,11.2 L9.4,15.4 Z')
    ctx.fill()
    path(ctx, 'M1.8,5.2 L9.5,9.4 C10.2,9.8 10.2,10.8 9.5,11.2 L1.8,15.4 Z')
    ctx.fill()
  },
  shuffle: (ctx) => {
    ctx.lineWidth = 1.7
    path(ctx, 'M2.6,5.6 L5.4,5.6 C6.6,5.6 7.7,6.1 8.5,6.9 L12.6,11.1 C13.4,11.9 14.5,12.4 15.7,12.4 L17.8,12.4')
    ctx.stroke()
    path(ctx, 'M2.6,14.4 L5.4,14.4 C6.6,14.4 7.7,13.9 8.5,13.1 L9.4,12.2 M12.1,9.4 L12.6,8.9 C13.4,8.1 14.5,7.6 15.7,7.6 L17.8,7.6')
    ctx.stroke()
    // the two arrowheads
    path(ctx, 'M15.6,5.2 L17.9,7.6 L15.6,9.9')
    ctx.stroke()
    path(ctx, 'M15.6,10.1 L17.9,12.4 L15.6,14.7')
    ctx.stroke()
  },
  repeat: (ctx) => {
    ctx.lineWidth = 1.7
    path(ctx, 'M5.8,5.9 L14.2,5.9 C15.9,5.9 17.2,7.2 17.2,8.9 L17.2,10.1')
    ctx.stroke()
    path(ctx, 'M7.9,3.6 L5.4,5.9 L7.9,8.2')
    ctx.stroke()
    path(ctx, 'M14.2,14.1 L5.8,14.1 C4.1,14.1 2.8,12.8 2.8,11.1 L2.8,9.9')
    ctx.stroke()
    path(ctx, 'M12.1,11.8 L14.6,14.1 L12.1,16.4')
    ctx.stroke()
  },
  'repeat.1': (ctx) => {
    SYMBOLS.repeat(ctx)
    path(ctx, 'M10,8.4 L10,10.4 M10,10.4 L10,10.4 M10,8.4 L9.1,9.1')
    ctx.lineWidth = 1.5
    ctx.stroke()
  },
  'speaker.wave.2.fill': (ctx) => {
    path(ctx, 'M3.2,7.4 L6.2,7.4 L10.4,3.8 C10.9,3.4 11.7,3.7 11.7,4.4 L11.7,15.6 C11.7,16.3 10.9,16.6 10.4,16.2 L6.2,12.6 L3.2,12.6 C2.6,12.6 2.2,12.2 2.2,11.6 L2.2,8.4 C2.2,7.8 2.6,7.4 3.2,7.4 Z')
    ctx.fill()
    ctx.lineWidth = 1.5
    for (const [r, a0, a1] of [[4.2, -0.9, 0.9], [7.0, -0.9, 0.9]]) {
      ctx.beginPath()
      ctx.arc(11.6, 10, r, a0, a1)
      ctx.stroke()
    }
  },
  'speaker.slash.fill': (ctx) => {
    path(ctx, 'M3.2,7.4 L6.2,7.4 L10.4,3.8 C10.9,3.4 11.7,3.7 11.7,4.4 L11.7,15.6 C11.7,16.3 10.9,16.6 10.4,16.2 L6.2,12.6 L3.2,12.6 C2.6,12.6 2.2,12.2 2.2,11.6 L2.2,8.4 C2.2,7.8 2.6,7.4 3.2,7.4 Z')
    ctx.fill()
    ctx.lineWidth = 1.5
    path(ctx, 'M13.6,7.2 L17.6,12.8 M17.6,7.2 L13.6,12.8')
    ctx.stroke()
  },
  'chevron.right': (ctx) => {
    ctx.lineWidth = 1.7
    path(ctx, 'M7.6,4.4 L13.2,10 L7.6,15.6')
    ctx.stroke()
  },
  'minus': (ctx) => {
    ctx.lineWidth = 1.6
    path(ctx, 'M4.6,10 L15.4,10')
    ctx.stroke()
  },
}

// ---------------------------------------------------------------- covers

const COVER_PALETTES = [
  { bg: '#22303A', ink: '#E8AE8C', alt: '#F4F1E8' },
  { bg: '#3A2A24', ink: '#F4F1E8', alt: '#E8AE8C' },
  { bg: '#1F2A26', ink: '#D9C7A7', alt: '#8FA79B' },
  { bg: '#2B2735', ink: '#E8AE8C', alt: '#C9C2D6' },
  { bg: '#4A3B2F', ink: '#F4F1E8', alt: '#D9A97F' },
  { bg: '#26313C', ink: '#DCE3E6', alt: '#7FA1B5' },
  { bg: '#3B2430', ink: '#F0D9C8', alt: '#C98A8A' },
  { bg: '#1E2B33', ink: '#E8AE8C', alt: '#9FB8C4' },
]

/**
 * A cover, drawn rather than fetched: a player that goes nowhere near the
 * network needs pictures that come from somewhere local, and for a screenshot
 * the local source is this file. Each one is a plate of its own colour with
 * one geometric mark — the sort of thing a record sleeve is.
 */
export function cover(ctx, x, y, size, seed = 0, radius = 0) {
  const p = COVER_PALETTES[seed % COVER_PALETTES.length]
  ctx.save()
  if (radius > 0) { roundRect(ctx, x, y, size, size, radius); ctx.clip() } else { ctx.beginPath(); ctx.rect(x, y, size, size); ctx.clip() }
  fillRect(ctx, p.bg, x, y, size, size)
  const shape = seed % 6 === 2 ? 5 : seed % 6
  const u = size / 100
  ctx.save()
  ctx.translate(x, y)
  ctx.globalAlpha = 0.95
  if (shape === 0) {
    // a horizon, and a disc over it
    fillRect(ctx, p.ink, 0, 64 * u, size, 36 * u)
    circle(ctx, 50 * u, 40 * u, 20 * u)
    ctx.fillStyle = p.ink
    ctx.fill()
  } else if (shape === 1) {
    // rings
    ctx.strokeStyle = p.ink
    ctx.lineWidth = 6 * u
    for (let k = 1; k <= 4; k++) { circle(ctx, 50 * u, 50 * u, k * 11 * u); ctx.stroke() }
    circle(ctx, 50 * u, 50 * u, 5 * u)
    ctx.fillStyle = p.alt
    ctx.fill()
  } else if (shape === 2) {
    // a wave, the player's own mark, at a sleeve's size
    ctx.strokeStyle = p.ink
    ctx.lineWidth = 7 * u
    ctx.lineCap = 'round'
    wavePath(ctx, 8 * u, 30 * u, 84 * u, 40 * u, 2, 96)
    ctx.stroke()
  } else if (shape === 3) {
    // bands
    for (let k = 0; k < 7; k++) {
      ctx.fillStyle = k % 3 === 1 ? p.alt : p.ink
      const w = (10 + ((seed + k * 7) % 30)) * u
      ctx.fillRect(12 * u, (14 + k * 11) * u, w, 4.5 * u)
    }
  } else if (shape === 4) {
    // an arc, turned
    ctx.strokeStyle = p.ink
    ctx.lineWidth = 9 * u
    ctx.beginPath()
    ctx.arc(50 * u, 74 * u, 40 * u, Math.PI, 2 * Math.PI)
    ctx.stroke()
    circle(ctx, 50 * u, 84 * u, 8 * u)
    ctx.fillStyle = p.alt
    ctx.fill()
  } else {
    // a triangle and its ground
    ctx.beginPath()
    ctx.moveTo(50 * u, 22 * u)
    ctx.lineTo(82 * u, 76 * u)
    ctx.lineTo(18 * u, 76 * u)
    ctx.closePath()
    ctx.fillStyle = p.ink
    ctx.fill()
    fillRect(ctx, p.alt, 18 * u, 82 * u, 64 * u, 4 * u)
  }
  ctx.restore()
  // the grain of a printed sleeve, barely there
  ctx.globalAlpha = 0.05
  for (let k = 0; k < 240; k++) {
    const gx = x + ((k * 37) % size)
    const gy = y + ((k * 91) % size)
    ctx.fillStyle = k % 2 ? '#FFFFFF' : '#000000'
    ctx.fillRect(gx, gy, 1, 1)
  }
  ctx.restore()
}
