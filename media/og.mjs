// The two social cards: the release's own face — 1200 x 630 for a link, and
// 1080 x 1080 for a post.
//
// Both are the same lockup in the series' colours: the icon, the name, the one
// line the app says about itself. The link card carries a picture of the
// window beside the words, because a card is where most people meet the app
// for the first time; the square is the lockup alone, because a post is read
// at thumbnail size.
//
//   node og.mjs <outDir>

import sharp from 'sharp'
import fs from 'node:fs'
import path from 'node:path'
import { makeCanvas, Palette, fillRect, text, ink, squirclePath } from './kit.mjs'
import { playerVertical, Metrics, surface, trafficLights } from './ui.mjs'
import { squirclePathData, wavePathData } from './icon.mjs'

const OUT = process.argv[2] ?? path.resolve(import.meta.dirname, '..', 'assets')

const CREAM = Palette.seriesText
const SECONDARY = Palette.seriesSecondary
const TERRACOTTA = Palette.seriesAccent
const GROUND = Palette.seriesGround
const QUIET = 'rgba(168,162,158,0.72)'

const track = {
  title: 'Полёт над городом',
  artist: 'Аня Ветрова',
  album: 'Стекло',
  duration: 252,
  position: 98,
  count: 7,
  playing: true,
  shuffle: false,
  repeat: 'all',
  muted: false,
  volume: 0.72,
  cover: null,
  paint: (ctx, x, y, size) => {
    // The window on the card wears the app's own "no cover" pane: the wave on
    // a pane so faint that it is a pane, which is what a file with no picture
    // gets. Nothing invented for the card.
    fillRect(ctx, ink('pane', 'dark'), x, y, size, size)
    ctx.save()
    ctx.strokeStyle = ink('faint', 'dark')
    ctx.lineWidth = size * 0.022
    ctx.lineCap = 'round'
    ctx.lineJoin = 'round'
    const start = x + size * 0.29
    const width = size * 0.42
    const mid = y + size / 2
    ctx.beginPath()
    for (let i = 0; i <= 96; i++) {
      const along = i / 96
      const px = start + width * along
      const py = mid - Math.sin(along * 2 * Math.PI * 2) * (size * 0.11)
      if (i === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.stroke()
    ctx.restore()
  },
}

/** A path reader for the icon's own data: absolute lines and one close. */
function path2(ctx, d) {
  const parts = d.split(/[MLZ]/).filter((s) => s.trim())
  ctx.beginPath()
  parts.forEach((part, i) => {
    const [px, py] = part.split(',').map(Number)
    if (i === 0) ctx.moveTo(px, py)
    else ctx.lineTo(px, py)
  })
  ctx.closePath()
}

/**
 * The app's icon, drawn from the very geometry the .icns is made of — on the
 * classic grid (a plate of 824 on the 1024 canvas), which is where the card's
 * layout was measured: the plate that fills the whole canvas is the rule for
 * the icon macOS wraps, not for a mark standing in a lockup.
 */
function glyph(ctx, x, y, size, { stroke = 74 } = {}) {
  const s = size / 1024
  ctx.save()
  ctx.translate(x, y)
  ctx.scale(s, s)
  ctx.fillStyle = GROUND
  path2(ctx, squirclePathData())
  ctx.fill()
  ctx.strokeStyle = TERRACOTTA
  ctx.lineWidth = stroke
  ctx.lineCap = 'round'
  ctx.lineJoin = 'round'
  path2(ctx, wavePathData())
  ctx.stroke()
  ctx.restore()
}

/** The warm light behind the lockup: one soft terracotta glow, barely there. */
function glow(ctx, x, y, r, strength = 0.12) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r)
  g.addColorStop(0, `rgba(232,174,140,${strength})`)
  g.addColorStop(0.5, `rgba(232,174,140,${strength * 0.3})`)
  g.addColorStop(1, 'rgba(232,174,140,0)')
  fillRect(ctx, g, x - r, y - r, r * 2, r * 2)
}

/** A picture of the window, standing on the card with its own edge showing. */
function windowPicture(ctx, x, y, w, h) {
  const band = Metrics.toolbar
  ctx.save()
  squirclePath(ctx, x, y, w, h, Metrics.windowCorner)
  ctx.clip()
  ctx.translate(x, y)
  surface(ctx, { x: 0, y: 0, w, h }, { theme: 'dark', glass: false })
  ctx.save()
  ctx.translate(0, band)
  playerVertical(ctx, { x: 0, y: 0, w, h: h - band }, track, { theme: 'dark' })
  ctx.restore()
  trafficLights(ctx, { x: 0, y: 0 })
  ctx.restore()
  // A hairline: a near-black window on a near-black ground has no edge of its
  // own, and a window with no edge is a hole in the card.
  ctx.save()
  ctx.strokeStyle = 'rgba(244,241,232,0.12)'
  ctx.lineWidth = 1
  squirclePath(ctx, x + 0.5, y + 0.5, w - 1, h - 1, Metrics.windowCorner)
  ctx.stroke()
  ctx.restore()
}

const jpeg = (canvas) =>
  sharp(canvas.toBuffer('image/png')).jpeg({ quality: 94, chromaSubsampling: '4:4:4' }).toBuffer()

// ---------------------------------------------------------------- 1200 x 630

async function link() {
  const W = 1200
  const H = 630
  const { canvas, ctx } = makeCanvas(W, H, 2)
  fillRect(ctx, GROUND, 0, 0, W, H)
  glow(ctx, 150, 560, 560, 0.10)
  glow(ctx, 1010, 90, 460, 0.055)

  const winW = 232
  const winH = 441
  windowPicture(ctx, W - winW - 120, (H - winH) / 2, winW, winH)

  // The lockup, as one block down the left: mark, name, what it is, what it
  // says, and the two facts a card is allowed at its foot.
  const x = 100
  const top = 122
  glyph(ctx, x, top, 104, { stroke: 68 })
  text(ctx, 'Dajet Player', x, top + 168, { size: 58, weight: 600, colour: CREAM })
  text(ctx, 'Тихий плеер для macOS', x, top + 222, { size: 26, weight: 400, colour: SECONDARY })
  text(ctx, 'Silence, playing.', x, top + 296, { size: 17, weight: 500, colour: TERRACOTTA, tracking: 1.4 })
  text(ctx, 'Quiet music player for macOS · MIT · free', x, top + 388, {
    size: 15, weight: 400, colour: QUIET,
  })

  fs.writeFileSync(`${OUT}/og-player-1200.jpg`, await jpeg(canvas))
  return { W, H }
}

// ---------------------------------------------------------------- 1080 x 1080

async function square() {
  const S = 1080
  const { canvas, ctx } = makeCanvas(S, S, 2)
  fillRect(ctx, GROUND, 0, 0, S, S)
  glow(ctx, S / 2, 430, 620, 0.10)

  const mark = 208
  glyph(ctx, (S - mark) / 2, 300, mark, { stroke: 68 })
  text(ctx, 'Dajet Player', S / 2, 618, { size: 66, weight: 600, colour: CREAM, align: 'center' })
  text(ctx, 'Тихий плеер для macOS', S / 2, 686, { size: 27, weight: 400, colour: SECONDARY, align: 'center' })
  text(ctx, 'Silence, playing.', S / 2, 772, { size: 19, weight: 500, colour: TERRACOTTA, align: 'center', tracking: 2.4 })
  text(ctx, 'Quiet music player for macOS · MIT · free', S / 2, 852, {
    size: 16, weight: 400, colour: QUIET, align: 'center',
  })
  text(ctx, 'dajet.ru', S / 2, 962, {
    size: 15, weight: 500, colour: 'rgba(168,162,158,0.45)', align: 'center', tracking: 1,
  })

  fs.writeFileSync(`${OUT}/og-player-1080.jpg`, await jpeg(canvas))
  return { S }
}

fs.mkdirSync(OUT, { recursive: true })
const a = await link()
const b = await square()
console.log(`og written: ${a.W}x${a.H}, ${b.S}x${b.S} -> ${OUT}`)
