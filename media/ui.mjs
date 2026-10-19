// The app's own widgets, drawn: the window, the toolbar, the player in both
// templates, and the side menu with its playlists.
//
// Every number in here is the app's. The layouts are read out of
// Sources/DajetPlayer/App.swift (`templatePlayer`, `templateNames`,
// `templateHands`, `templateVolume`, `progress`), Side.swift (the column and
// its rows) and Design.swift (Metrics, Door, Wave). Where the app asks SwiftUI
// for a frame, this asks for the same frame; nothing is nudged to look better,
// because a screenshot that has been nudged is no longer of the app.

import {
  Palette, Glass, ink, fillRect, strokeRect, roundRect, circle, wavePath, text, width,
  clipText, symbol, symbolFilled, squirclePath, alpha, SF,
} from './kit.mjs'

export const Metrics = {
  door: 26,
  side: 232,
  sideMin: 176,
  sideMax: 440,
  gap: 10,
  row: 26,
  corner: 8,
  panel: 12,
  sleeve: 272,
  toolbar: 52,
  windowCorner: 10,
}

// ---------------------------------------------------------------- the window

/**
 * The window's surface, under everything: the light theme's glass over a
 * desktop (Window.swift's recipe — the material at density 0.78, the lift,
 * the sheen across the top 64 points, the foot, and the rim), or the dark
 * theme's matte, which is one colour and the shadow of a gradient on it.
 *
 * `backdrop` is the desktop behind the window: an image, already sampled where
 * the window is, or nothing at all for the opaque case.
 */
export function surface(ctx, rect, { theme, glass, backdrop }) {
  const { x, y, w, h } = rect
  ctx.save()
  squirclePath(ctx, x, y, w, h, Metrics.windowCorner)
  ctx.clip()

  if (glass && backdrop) {
    // The material (Window.swift, `Glass`): the desktop behind the window,
    // sampled over a little more than the window itself so that the blur has
    // something to work with at the edges, blurred at the density the app
    // asks for, with the rest of it coming through unblurred beneath — which
    // is what a material at less than full density is.
    ctx.save()
    ctx.globalAlpha = 0.78
    ctx.filter = 'blur(34px)'
    backdrop(ctx, x - 60, y - 60, w + 120, h + 120)
    ctx.restore()
    ctx.save()
    ctx.globalAlpha = 0.22
    backdrop(ctx, x - 60, y - 60, w + 120, h + 120)
    ctx.restore()
    fillRect(ctx, Glass.lift, x, y, w, h)
    const sheen = ctx.createLinearGradient(0, y, 0, y + 64)
    sheen.addColorStop(0, Glass.sheen)
    sheen.addColorStop(1, 'rgba(255,255,255,0)')
    fillRect(ctx, sheen, x, y, w, 64)
    const foot = ctx.createLinearGradient(0, y + h - 120, 0, y + h)
    foot.addColorStop(0, 'rgba(0,0,0,0)')
    foot.addColorStop(1, Glass.foot)
    fillRect(ctx, foot, x, y + h - 120, w, 120)
  } else if (glass) {
    // Glass with the Mac asked for less transparency: the pale solid instead.
    fillRect(ctx, Palette.ground.light, x, y, w, h)
  } else {
    fillRect(ctx, ink('ground', theme), x, y, w, h)
    const shade = ctx.createLinearGradient(0, y, 0, y + h)
    shade.addColorStop(0, 'rgba(0,0,0,0.32)')
    shade.addColorStop(1, 'rgba(0,0,0,0)')
    fillRect(ctx, shade, x, y, w, h)
  }

  // The rim: one point of light at the top-left of the glass and a whisper of
  // dark at its foot.
  if (glass) {
    const rim = ctx.createLinearGradient(x, y, x + w, y + h)
    rim.addColorStop(0, 'rgba(255,255,255,0.32)')
    rim.addColorStop(0.5, 'rgba(255,255,255,0.04)')
    rim.addColorStop(1, 'rgba(0,0,0,0.08)')
    strokeRect(ctx, rim, x, y, w, h, Metrics.windowCorner, 1)
  }
  ctx.restore()
}

/** The three lights in the window's corner, in the system's three colours. */
export function trafficLights(ctx, rect) {
  const { x, y } = rect
  const colours = ['#FF5F57', '#FEBC2E', '#28C840']
  colours.forEach((c, k) => {
    circle(ctx, x + 20 + k * 20, y + 26, 6)
    ctx.fillStyle = c
    ctx.fill()
  })
}

/** The system's own toolbar: the toggle beside the lights, the rest at the far end. */
export function toolbar(ctx, rect, { theme, sidebarOpen, showAddFolder = true, showTheme = true, themeIcon = 'sun.max' }) {
  const { x, y, w } = rect
  const cy = y + 26
  const tone = ink('muted', theme)
  ctx.save()
  symbol(ctx, 'sidebar.leading', x + 94, cy, 17, sidebarOpen ? ink('ink', theme) : tone, 1.5)
  const trailing = []
  if (showTheme) trailing.push(themeIcon)
  if (showAddFolder) trailing.push('folder.badge.plus')
  let tx = x + w - 26
  for (const name of trailing) {
    // The badge sits on the ground it is drawn over; it is not a window of
    // its own and must not be a black circle in the middle of the glass.
    symbol(ctx, name, tx, cy, 17, tone, 1.5)
    tx -= 32
  }
  ctx.restore()
}

// ---------------------------------------------------------------- one door

/**
 * `Door` (Design.swift): a glyph in a rounded square, washed under the pointer
 * and in the accent while it is on.
 */
export function door(ctx, x, y, name, opts = {}) {
  const {
    theme = 'light', on = false, hover = false, enabled = true, size = Metrics.door,
    glyph = 11, filled = true, ground = null,
  } = opts
  ctx.save()
  if (on) fillRect(ctx, ink('wash', theme), x, y, size, size, Metrics.corner)
  else if (hover && enabled) fillRect(ctx, ink('hover', theme), x, y, size, size, Metrics.corner)
  let colour
  if (!enabled) colour = ink('faint', theme)
  else if (on) colour = ink('accent', theme)
  else if (hover) colour = alpha(ink('ink', theme), 0.8)
  else colour = ink('muted', theme)
  if (!enabled) ctx.globalAlpha = 0.35
  const cx = x + size / 2
  const cy = y + size / 2
  if (name.startsWith('pause') || name.startsWith('play') || name.startsWith('backward') || name.startsWith('forward') || name === 'speaker.wave.2.fill' || name === 'speaker.slash.fill') {
    symbolFilled(ctx, name, cx, cy, glyph * 1.05, colour)
  } else {
    symbol(ctx, name, cx, cy, glyph * 1.1, colour, 1.7)
  }
  ctx.restore()
}

// ---------------------------------------------------------------- the player

/** The two times and the line between them (`progress`). */
function progress(ctx, x, y, w, height, data, { theme, tight, hover = false }) {
  const labelW = tight ? 38 : 46
  const gap = tight ? 8 : 12
  const tone = ink('faint', theme)
  const whole = data.duration || 0
  const filled = whole > 0 ? Math.min(Math.max((data.position || 0) / whole, 0), 1) : 0
  const clock = (s) => {
    const t = Math.max(0, Math.round(s))
    const hh = Math.floor(t / 3600)
    const mm = Math.floor((t % 3600) / 60)
    const ss = t % 60
    return hh > 0
      ? `${hh}:${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`
      : `${mm}:${String(ss).padStart(2, '0')}`
  }
  const cy = y + height / 2
  text(ctx, clock(data.position || 0), x + labelW, cy, { size: 11, weight: 500, colour: tone, align: 'right' })
  const bx = x + labelW + gap
  const bw = w - labelW * 2 - gap * 2
  const line = hover ? 6 : 4
  const by = cy - line / 2
  fillRect(ctx, ink('hairline', theme), bx, by, bw, line, line / 2)
  if (filled > 0) fillRect(ctx, ink('accent', theme), bx, by, Math.max(line, bw * filled), line, line / 2)
  if (hover) {
    ctx.save()
    ctx.shadowColor = 'rgba(0,0,0,0.25)'
    ctx.shadowBlur = 3
    ctx.shadowOffsetY = 1
    circle(ctx, bx + bw * filled, cy, 5)
    ctx.fillStyle = ink('accent', theme)
    ctx.fill()
    ctx.restore()
  }
  if (whole > 0) text(ctx, '-' + clock(whole - (data.position || 0)), x + w - labelW, cy, { size: 11, weight: 500, colour: tone, align: 'left' })
}

const repeatGlyph = (mode) => (mode === 'one' ? 'repeat.1' : 'repeat')

/** The three hands, and the volume row under them. */
function hands(ctx, x, y, w, data, { theme, hoverPlay }) {
  const size = Metrics.door
  const gap = 12
  const total = size * 3 + gap * 2
  let cx = x + (w - total) / 2
  const cy = y
  door(ctx, cx, cy, 'backward.fill', { theme, enabled: data.count > 0 })
  door(ctx, cx + size + gap, cy, data.playing ? 'pause.fill' : 'play.fill', { theme, on: true, enabled: data.count > 0, hover: hoverPlay })
  door(ctx, cx + (size + gap) * 2, cy, 'forward.fill', { theme, enabled: data.count > 0 })
}

function volumeRow(ctx, x, y, w, data, { theme }) {
  const size = 22
  const gap = 8
  door(ctx, x, y, 'shuffle', { theme, size, glyph: 11, on: !!data.shuffle })
  door(ctx, x + size + gap, y, repeatGlyph(data.repeat), { theme, size, glyph: 11, on: data.repeat !== 'off' })
  door(ctx, x + (size + gap) * 2, y, data.muted ? 'speaker.slash.fill' : 'speaker.wave.2.fill', { theme, size, glyph: 11, on: !!data.muted })
  // The slider: a mini one, the accent under the knob as SwiftUI draws it.
  const sx = x + (size + gap) * 3
  const sw = w - (size + gap) * 3
  const cy = y + 11
  const v = Math.min(Math.max(data.volume ?? 0.72, 0), 1)
  fillRect(ctx, ink('hairline', theme), sx, cy - 1, sw, 2, 1)
  fillRect(ctx, ink('accent', theme), sx, cy - 1, sw * v, 2, 1)
  circle(ctx, sx + sw * v, cy, 5)
  ctx.fillStyle = ink('accent', theme)
  ctx.fill()
}

const names = (ctx, x, y, w, data, { theme, titleHeight, subtitleHeight }) => {
  text(ctx, data.title, x + w / 2, y + titleHeight / 2, {
    size: 15, weight: 600, colour: ink('ink', theme), align: 'center', maxWidth: w,
  })
  const sub = [data.artist, data.album].filter(Boolean).join(' · ')
  text(ctx, sub, x + w / 2, y + titleHeight + subtitleHeight / 2, {
    size: 13, weight: 400, colour: ink('muted', theme), align: 'center', maxWidth: w,
  })
}

/** The sleeve, cut with the window's own continuous corner and its hairline. */
function sleeve(ctx, x, y, size, data, { theme }) {
  const r = Metrics.panel + 2
  ctx.save()
  squirclePath(ctx, x, y, size, size, r)
  ctx.clip()
  if (data.cover === null) {
    fillRect(ctx, ink('pane', theme), x, y, size, size)
    ctx.strokeStyle = ink('faint', theme)
    ctx.lineWidth = 3
    ctx.lineCap = 'round'
    wavePath(ctx, x + size * 0.29, y + size * 0.39, size * 0.42, size * 0.22, 2, 96)
    ctx.stroke()
  } else {
    // eslint-disable-next-line no-undef
    data.paint(ctx, x, y, size)
  }
  ctx.restore()
  strokeRect(ctx, ink('hairline', theme), x, y, size, size, r, 1)
  ctx.save()
  ctx.shadowColor = 'rgba(0,0,0,0.30)'
  ctx.shadowBlur = 22
  ctx.shadowOffsetY = 12
  strokeRect(ctx, ink('hairline', theme), x, y, size, size, r, 1)
  ctx.restore()
}

/**
 * The horizontal template: the sleeve on the left, everything else beside it.
 * `drawer` is the app's own word for the window with the column out over it,
 * which is narrower and loses the volume row.
 */
export function playerHorizontal(ctx, rect, data, { theme, drawer = false, playHover = false }) {
  const { x, y, w, h } = rect
  const spacing = drawer ? 12 : 16
  const padX = drawer ? 12 : 16
  const art = Math.min(drawer ? 160 : 200, Math.max(0, h - 20), Math.max(0, w - (drawer ? 188 : 200)))
  const columnX = x + padX + art + spacing
  const columnW = w - padX * 2 - art - spacing
  const stackH = drawer ? 40 + 16 + 8 + 14 + 8 + 26 : 40 + 18 + 14 + 16 + 12 + 26 + 12 + 24
  const top = y + (h - stackH) / 2
  let cy = top
  if (drawer) {
    names(ctx, columnX, cy, columnW, data, { theme, titleHeight: 40, subtitleHeight: 16 })
    cy += 40 + 16 + 8
    progress(ctx, columnX, cy, columnW, 14, data, { theme, tight: true })
    cy += 14 + 8
    hands(ctx, columnX, cy, columnW, data, { theme, hoverPlay: playHover })
  } else {
    names(ctx, columnX, cy, columnW, data, { theme, titleHeight: 40, subtitleHeight: 18 })
    cy += 40 + 18 + 14
    progress(ctx, columnX, cy, columnW, 16, data, { theme, tight: true })
    cy += 16 + 12
    hands(ctx, columnX, cy, columnW, data, { theme, hoverPlay: playHover })
    cy += 26 + 12
    volumeRow(ctx, columnX, cy, columnW, data, { theme })
  }
  sleeve(ctx, x + padX, y + (h - art) / 2, art, data, { theme })
}

/** The vertical template: one column, the sleeve at the top of it. */
export function playerVertical(ctx, rect, data, { theme, playHover = false }) {
  const { x, y, w, h } = rect
  const art = Math.min(200, Math.max(0, w - 32), Math.max(0, h - 176))
  const stackH = art + 10 + 36 + 16 + 8 + 14 + 10 + 26 + 10 + 22
  const top = y + (h - (stackH + 24)) / 2 + 12
  const cx = x + w / 2
  sleeve(ctx, cx - art / 2, top, art, data, { theme })
  let cy = top + art + 10
  names(ctx, x + 16, cy, w - 32, data, { theme, titleHeight: 36, subtitleHeight: 16 })
  cy += 36 + 16 + 8
  progress(ctx, x + 16, cy, w - 32, 14, data, { theme, tight: true })
  cy += 14 + 10
  hands(ctx, x + 16, cy, w - 32, data, { theme, hoverPlay: playHover })
  cy += 26 + 10
  volumeRow(ctx, x + 16, cy, w - 32, data, { theme })
}

/** Nothing opened: the invitation, which is what a fresh copy of the app says. */
export function playerIdle(ctx, rect, { theme, tight = true, note = null }) {
  const { x, y, w, h } = rect
  const lines = note
    ? [note]
    : ['Drop a folder of music, or a few files.', 'It plays in the order the Finder lists it.']
  const blockH = 28 + 10 + lines.length * 18 + 12 + 26 + 10 + 22
  let cy = y + (h - blockH) / 2
  ctx.save()
  ctx.strokeStyle = note ? ink('faint', theme) : ink('accent', theme)
  ctx.lineWidth = note ? 2.5 : 3
  ctx.lineCap = 'round'
  wavePath(ctx, x + w / 2 - 32, cy, 64, 28, 2, 96)
  ctx.stroke()
  ctx.restore()
  cy += 28 + 10
  lines.forEach((line, k) => {
    text(ctx, line, x + w / 2, cy + k * 18 + 9, {
      size: k === 0 ? 13 : 11,
      weight: k === 0 ? 400 : 400,
      colour: k === 0 ? ink('ink', theme) : ink('muted', theme),
      align: 'center', maxWidth: w - 24,
    })
  })
  cy += lines.length * 18 + 12
  const idle = { title: '', artist: '', album: '', duration: 0, position: 0, count: 0, playing: false, shuffle: false, repeat: 'off', muted: false, volume: 0.72 }
  hands(ctx, x, cy, w, idle, { theme, hoverPlay: false })
  cy += 26 + 10
  volumeRow(ctx, x + (w - Math.min(200, w)) / 2, cy, Math.min(200, w), idle, { theme })
}

// ---------------------------------------------------------------- the column

/**
 * The side menu (Side.swift): a step off the window's own surface, with
 * playlists in it and the tracks of the one that is open under its name.
 */
export function sideMenu(ctx, rect, { theme, playlists, openId, playingId, playingTrack, hoverId = null, hoverTrack = null }) {
  const { x, y, w, h } = rect
  ctx.save()
  // The shadow it casts on the player, then the tile itself.
  ctx.shadowColor = 'rgba(0,0,0,0.18)'
  ctx.shadowBlur = 14
  ctx.shadowOffsetX = 4
  fillRect(ctx, ink('side', theme), x, y, w, h)
  ctx.restore()
  fillRect(ctx, ink('hairline', theme), x + w - 1, y, 1, h)

  let cy = y + Metrics.gap
  if (!playlists.length) {
    text(ctx, 'No playlists yet.', x + 16, cy + 6, { size: 12, weight: 500, colour: ink('muted', theme) })
    text(ctx, 'Add a folder above, or drop one on the window:', x + 16, cy + 26, { size: 11, colour: ink('faint', theme) })
    text(ctx, 'it stays here, and it plays.', x + 16, cy + 40, { size: 11, colour: ink('faint', theme) })
    return
  }
  text(ctx, 'PLAYLISTS', x + 16, cy + 6, { size: 10, weight: 500, colour: ink('faint', theme), tracking: 0.7 })
  cy += 10 + 4
  const rowH = Metrics.row
  for (const pl of playlists) {
    const open = pl.id === openId
    const current = pl.id === playingId
    const rx = x + 8
    const rw = w - 16
    cy += 2
    // the row
    if (hoverId === pl.id) fillRect(ctx, ink('hover', theme), rx + 4, cy, rw - 4, rowH, Metrics.corner)
    symbol(ctx, 'chevron.right', rx + 4 + 9, cy + rowH / 2, 9 * 1.25, ink('faint', theme), 1.9)
    const nameX = rx + 4 + 18 + 2
    const nameW = rw - 4 - 18 - 2 - 8
    clipText(ctx, pl.name, nameX, cy + rowH / 2, nameW - (current ? 16 : 0), {
      size: 13, weight: current ? 600 : 400, colour: current ? ink('accent', theme) : ink('ink', theme),
    })
    if (current) symbolFilled(ctx, 'speaker.wave.2.fill', rx + rw - 12, cy + rowH / 2, 11, ink('accent', theme))
    cy += rowH
    if (open) {
      for (const [i, track] of pl.tracks.entries()) {
        const playing = current && track === playingTrack
        if (playing) fillRect(ctx, ink('wash', theme), rx + 4, cy, rw - 4, rowH, Metrics.corner)
        else if (hoverTrack === track) fillRect(ctx, ink('hover', theme), rx + 4, cy, rw - 4, rowH, Metrics.corner)
        text(ctx, String(i + 1), rx + 4 + 24 + 16, cy + rowH / 2, {
          size: 10, weight: 500, colour: playing ? ink('accent', theme) : ink('faint', theme), align: 'right',
        })
        clipText(ctx, track, rx + 4 + 24 + 16 + 6, cy + rowH / 2, rw - 4 - 24 - 16 - 6 - 8, {
          size: 12, colour: playing ? ink('accent', theme) : ink('ink', theme),
        })
        cy += rowH + 1
      }
    }
    cy += 1
  }
}

// ---------------------------------------------------------------- backdrop

/**
 * A desktop for the glass to be glass over: warm, out of focus, and nothing
 * anybody would mistake for a place. `seed` picks one of the plates.
 */
export function desktop(ctx, x0, y0, w, h, seed = 0) {
  const plates = [
    ['#EFE7DB', '#D6C4B0', '#C98A63'],
    ['#E8E2DA', '#CFC3B8', '#8E9AA4'],
    ['#F1E6D8', '#D9BFA4', '#7E8A94'],
  ]
  const [a, b, c] = plates[seed % plates.length]
  const g = ctx.createLinearGradient(x0, y0, x0 + w, y0 + h)
  g.addColorStop(0, a)
  g.addColorStop(0.55, b)
  g.addColorStop(1, '#B9AC9E')
  fillRect(ctx, g, x0, y0, w, h)
  ctx.save()
  ctx.filter = 'blur(70px)'
  const blobs = [
    [x0 + w * 0.22, y0 + h * 0.28, w * 0.30, 0.55],
    [x0 + w * 0.82, y0 + h * 0.22, w * 0.26, 0.45],
    [x0 + w * 0.62, y0 + h * 0.86, w * 0.34, 0.5],
  ]
  blobs.forEach(([bx, by, br, op], k) => {
    ctx.globalAlpha = op
    circle(ctx, bx, by, br)
    ctx.fillStyle = k === 1 ? c : k === 2 ? '#9AA3AA' : '#C08A5E'
    ctx.fill()
  })
  ctx.restore()
  ctx.save()
  ctx.globalAlpha = 0.12
  for (let k = 0; k < 1200; k++) {
    const gx = x0 + ((k * 97) % w)
    const gy = y0 + ((k * 53) % h)
    ctx.fillStyle = k % 2 ? '#FFFFFF' : '#000000'
    ctx.fillRect(gx, gy, 1, 1)
  }
  ctx.restore()
}
