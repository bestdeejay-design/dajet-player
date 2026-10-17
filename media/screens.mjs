// The five promo screenshots, drawn from the app's own layout.
//
// The two templates are shot at the exact frames the app measures itself in —
// 548 x 284 and 232 x 441 from Presentation.swift, the *window* rather than its
// content, because that is what the toolbar is inside of. The two custom ones
// are as wide as their content wants; nothing in the app forces a size on a
// window somebody has resized by hand.
//
//   node screens.mjs <assetsDir>      (writes <assetsDir>/screenshots/)
//
// One shot per file, 2x, the window filling the picture: no bezel of our own
// around a window that has its own corners, so the PNG drops into a README on
// a dark page and on a light one without a white box behind it.

import fs from 'node:fs'
import path from 'node:path'
import { makeCanvas, writePNG, cover, squirclePath } from './kit.mjs'
import { surface, trafficLights, toolbar, Metrics, playerHorizontal, playerVertical, playerIdle, sideMenu, desktop, door } from './ui.mjs'

const ASSETS = process.argv[2] ?? path.resolve(import.meta.dirname, '..', 'assets')
const OUT = path.join(ASSETS, 'screenshots')

// ---------------------------------------------------------------- the sample

const coverPainter = (seed) => (ctx, x, y, size) => cover(ctx, x, y, size, seed)

const track = {
  'Полёт над городом': {
    title: 'Полёт над городом',
    artist: 'Аня Ветрова',
    album: 'Стекло',
    duration: 252,
    position: 98,
    count: 7,
    number: 3,
    playing: true,
    shuffle: false,
    repeat: 'all',
    muted: false,
    volume: 0.72,
    cover: 4,
    paint: coverPainter(4),
  },
}

const playlists = [
  {
    id: 'night',
    name: 'Ночные поезда',
    tracks: ['Северный ветер', 'Тихий дождь на Приморской', 'Полёт над городом', 'Последний трамвай', 'Стекло и вода'],
  },
  { id: 'morning', name: 'Утренний свет', tracks: ['Медленное утро', 'Чай на подоконнике'] },
  { id: 'walk', name: 'Long walk home', tracks: ['Ferry', 'Wet asphalt'] },
]

const idleData = {
  title: '', artist: '', album: '', duration: 0, position: 0, count: 0, playing: false,
  shuffle: false, repeat: 'off', muted: false, volume: 0.72, cover: null,
}

// ---------------------------------------------------------------- the frame

/**
 * One window, drawn: the surface, the toolbar the system gives it, and
 * whatever the caller paints in the room below the band.
 */
function window_(w, h, opts) {
  const { theme = 'light', glass = false, desktopSeed = 0, shadow = false, sidebarOpen = false, themeIcon = 'sun.max', paint } = opts
  const { canvas, ctx } = makeCanvas(w, h, 2)
  const rect = { x: 0, y: 0, w, h }
  const band = Metrics.toolbar
  const content = { x: 0, y: band, w, h: h - band }

  // What is behind the window: a desktop, when there is one to be behind it.
  if (shadow) desktop(ctx, -120, -120, w + 240, h + 240, desktopSeed)

  if (shadow) {
    // The window's own shadow, cast by the shape it is.
    ctx.save()
    ctx.shadowColor = 'rgba(0,0,0,0.38)'
    ctx.shadowBlur = 48
    ctx.shadowOffsetY = 18
    squirclePath(ctx, 0, 0, w, h, Metrics.windowCorner)
    ctx.fillStyle = '#000'
    ctx.fill()
    ctx.restore()
  }

  ctx.save()
  squirclePath(ctx, 0, 0, w, h, Metrics.windowCorner)
  ctx.clip()
  surface(ctx, rect, {
    theme,
    glass,
    backdrop: glass ? (c, x, y, ww, hh) => desktop(c, x, y, ww, hh, desktopSeed) : null,
  })
  paint(ctx, content, { theme, glass })
  trafficLights(ctx, rect)
  toolbar(ctx, rect, { theme, sidebarOpen, themeIcon })
  ctx.restore()

  return { canvas, ctx, content }
}

// ---------------------------------------------------------------- the shots

fs.mkdirSync(OUT, { recursive: true })

async function horizontalPlaying() {
  // Horizontal — 548 x 284 (Presentation.swift, WindowTemplate.horizontal),
  // of which the system toolbar owns 52: the content is 548 x 232.
  const { canvas } = window_(548, 284, {
    theme: 'light',
    glass: true,
    desktopSeed: 0,
    paint: (ctx, content, { theme }) => {
      playerHorizontal(ctx, content, track['Полёт над городом'], { theme })
    },
  })
  await writePNG(canvas, `${OUT}/horizontal-playing.png`)
}

async function verticalPlaying() {
  // Vertical — 232 x 441, the tallest thing this player is: content 232 x 389.
  const { canvas } = window_(232, 441, {
    theme: 'light',
    glass: true,
    desktopSeed: 0,
    paint: (ctx, content, { theme }) => {
      playerVertical(ctx, content, track['Полёт над городом'], { theme })
    },
  })
  await writePNG(canvas, `${OUT}/vertical-playing.png`)
}

async function obsidian() {
  // The same Vertical frame in the dark theme (the app's Obsidian preset).
  const { canvas } = window_(232, 441, {
    theme: 'dark',
    glass: false,
    paint: (ctx, content, { theme }) => {
      playerVertical(ctx, content, track['Полёт над городом'], { theme })
    },
    themeIcon: 'circle.lefthalf.filled',
  })
  await writePNG(canvas, `${OUT}/obsidian.png`)
}

async function sideMenuShot() {
  // A custom window, wide enough to be the horizontal layout: the column at
  // its resting 232 points, the player pushed over beside it (the app's own
  // drawer, App.swift), and the toolbar's toggle saying the menu is out.
  const W = 700
  const H = 420
  const { canvas } = window_(W, H, {
    theme: 'light',
    glass: true,
    desktopSeed: 0,
    sidebarOpen: true,
    paint: (ctx, content, { theme }) => {
      const column = Metrics.side
      playerHorizontal(
        ctx,
        { x: column, y: content.y, w: W - column, h: content.h },
        track['Полёт над городом'],
        { theme, drawer: true },
      )
      sideMenu(ctx, { x: 0, y: content.y, w: column, h: content.h }, {
        theme, playlists, openId: 'night', playingId: 'night', playingTrack: 'Полёт над городом',
      })
    },
  })
  await writePNG(canvas, `${OUT}/side-menu.png`)
}

async function glassDesktop() {
  const W = 820
  const H = 560
  const { canvas } = window_(W, H, {
    theme: 'light',
    glass: true,
    desktopSeed: 2,
    shadow: true,
    paint: (ctx, content, { theme }) => {
      playerHorizontal(ctx, content, track['Полёт над городом'], { theme })
    },
  })
  await writePNG(canvas, `${OUT}/glass-desktop.png`)
}

await horizontalPlaying()
await verticalPlaying()
await obsidian()
await sideMenuShot()
await glassDesktop()
console.log('screens written to', OUT)
