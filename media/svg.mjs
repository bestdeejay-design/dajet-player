// header.svg and footer.svg — the two pictures the README wears.
//
// The pattern is the browser's (dajet-browser/assets/header.svg): one
// animated wave along the foot, the name over it, the series' colours. What is
// the player's own is what the wave carries: a window of its own — glass, a
// cover, the transport — drawn at the app's real sizes and then put on the
// banner as a picture of the app rather than an artist's idea of it.
//
// Written as SVG by hand, because these two files are the ones that must not
// be a raster: they are read at whatever width a README happens to be.
//
//   node svg.mjs <assetsDir>

import fs from 'node:fs'
import path from 'node:path'
import { squirclePathData, wavePathData } from './mark.mjs'

const GROUND = '#15181C'
const CREAM = '#F4F1E8'
const SECONDARY = '#A8A29E'
const TERRACOTTA = '#E8AE8C'

const FACE = "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', 'Helvetica Neue', Arial, sans-serif"

/** One line of text, centred on its cap height the way the app's layouts are. */
function text(str, x, y, { size = 16, weight = 400, fill = CREAM, anchor = 'start', tracking = 0, family = FACE, opacity = 1, baseline = false } = {}) {
  const yy = baseline ? y : y + size * 0.727 / 2
  const spread = tracking ? ` letter-spacing="${tracking}"` : ''
  const op = opacity !== 1 ? ` opacity="${opacity}"` : ''
  return `<text x="${x}" y="${yy.toFixed(2)}" font-family="${family}" font-size="${size}" font-weight="${weight}" fill="${fill}" text-anchor="${anchor}"${spread}${op}>${str}</text>`
}

const rect = (x, y, w, h, fill, extra = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"${extra}/>`

const round = (x, y, w, h, r, fill, extra = '') =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" ry="${r}" fill="${fill}"${extra}/>`

/** The icon's squircle, at whatever size it is asked for. */
function mark(x, y, size, { stroke = 74, steps = 10 } = {}) {
  const s = size / 1024
  return `<g transform="translate(${x},${y}) scale(${s})">
    <path d="${squirclePathData(112, 824, 824 * 0.2253, steps)}" fill="${GROUND}"/>
    <path d="${wavePathData(596, 244, 2, 84)}" fill="none" stroke="${TERRACOTTA}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"/>
  </g>`
}

/**
 * A sine as a path, in the coordinates the banner draws in. `phase` moves it
 * along; used both for the still frame and for the animation's key values.
 */
function wave(x, y, w, amplitude, crests, phase = 0, steps = 96) {
  const pts = []
  for (let i = 0; i <= steps; i++) {
    const along = i / steps
    pts.push([
      x + w * along,
      y - Math.sin((along * crests + phase) * 2 * Math.PI) * amplitude,
    ])
  }
  return 'M' + pts.map(([px, py]) => `${px.toFixed(2)},${py.toFixed(2)}`).join('L')
}

const SYMBOLS = {
  sidebar: (x, y, colour) => `
    <g transform="translate(${x},${y})" fill="none" stroke="${colour}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
      <rect x="2" y="3.4" width="16" height="13.2" rx="3.6"/>
      <path d="M7.4,3.4 L7.4,16.6"/>
      <path d="M7.4,14.8 L4.6,14.8 C3.4,14.8 2.6,14.1 2.6,13.2 L2.6,6.8 C2.6,5.9 3.4,5.2 4.6,5.2 L7.4,5.2 Z" fill="${colour}" stroke="none"/>
    </g>`,
  folder: (x, y, colour) => `
    <g transform="translate(${x},${y})" fill="none" stroke="${colour}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
      <path d="M2.4,6.4 C2.4,5.3 3.2,4.6 4.3,4.6 L7.1,4.6 C7.7,4.6 8.2,4.9 8.5,5.3 L9.2,6.4 L15.7,6.4 C16.8,6.4 17.6,7.2 17.6,8.3 L17.6,14.2 C17.6,15.3 16.8,16 15.7,16 L4.3,16 C3.2,16 2.4,15.3 2.4,14.2 Z"/>
      <circle cx="15.2" cy="15.2" r="4.6" fill="rgba(255,255,255,0.55)" stroke="none"/>
      <path d="M15.2,13.3 L15.2,17.1 M13.3,15.2 L17.1,15.2" stroke-width="1.4"/>
    </g>`,
  sun: (x, y, colour) => {
    const spokes = Array.from({ length: 8 }, (_, k) => {
      const a = (k * Math.PI) / 4
      return `<path d="M${(10 + Math.cos(a) * 6.2).toFixed(2)},${(10 + Math.sin(a) * 6.2).toFixed(2)} L${(10 + Math.cos(a) * 8.1).toFixed(2)},${(10 + Math.sin(a) * 8.1).toFixed(2)}"/>`
    }).join('')
    return `<g transform="translate(${x},${y})" fill="none" stroke="${colour}" stroke-width="1.6" stroke-linecap="round">
      <circle cx="10" cy="10" r="3.6"/>${spokes}
    </g>`
  },
  play: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.62)"><path d="M5.4,2.9 C5.4,1.9 6.5,1.3 7.4,1.8 L17.3,8.5 C18.1,9 18.1,10.2 17.3,10.7 L7.4,17.4 C6.5,17.9 5.4,17.3 5.4,16.3 Z" fill="${colour}"/></g>`,
  pause: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.62)"><rect x="4.2" y="2.6" width="4.4" height="14.8" rx="1.5" fill="${colour}"/><rect x="11.4" y="2.6" width="4.4" height="14.8" rx="1.5" fill="${colour}"/></g>`,
  back: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.62)"><path d="M10.6,5.2 L2.9,9.4 C2.2,9.8 2.2,10.8 2.9,11.2 L10.6,15.4 Z" fill="${colour}"/><path d="M18.2,5.2 L10.5,9.4 C9.8,9.8 9.8,10.8 10.5,11.2 L18.2,15.4 Z" fill="${colour}"/></g>`,
  next: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.62)"><path d="M9.4,5.2 L17.1,9.4 C17.8,9.8 17.8,10.8 17.1,11.2 L9.4,15.4 Z" fill="${colour}"/><path d="M1.8,5.2 L9.5,9.4 C10.2,9.8 10.2,10.8 9.5,11.2 L1.8,15.4 Z" fill="${colour}"/></g>`,
  shuffle: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.55)" fill="none" stroke="${colour}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
      <path d="M2.6,5.6 L5.4,5.6 C6.6,5.6 7.7,6.1 8.5,6.9 L12.6,11.1 C13.4,11.9 14.5,12.4 15.7,12.4 L17.8,12.4"/>
      <path d="M2.6,14.4 L5.4,14.4 C6.6,14.4 7.7,13.9 8.5,13.1 L9.4,12.2 M12.1,9.4 L12.6,8.9 C13.4,8.1 14.5,7.6 15.7,7.6 L17.8,7.6"/>
      <path d="M15.6,5.2 L17.9,7.6 L15.6,9.9"/><path d="M15.6,10.1 L17.9,12.4 L15.6,14.7"/>
    </g>`,
  repeat: (x, y, colour) => `<g transform="translate(${x},${y}) scale(0.55)" fill="none" stroke="${colour}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
      <path d="M5.8,5.9 L14.2,5.9 C15.9,5.9 17.2,7.2 17.2,8.9 L17.2,10.1"/><path d="M7.9,3.6 L5.4,5.9 L7.9,8.2"/>
      <path d="M14.2,14.1 L5.8,14.1 C4.1,14.1 2.8,12.8 2.8,11.1 L2.8,9.9"/><path d="M12.1,11.8 L14.6,14.1 L12.1,16.4"/>
    </g>`,
  speaker: (x, y, colour, muted = false) => `<g transform="translate(${x},${y}) scale(0.5)">
      <path d="M3.2,7.4 L6.2,7.4 L10.4,3.8 C10.9,3.4 11.7,3.7 11.7,4.4 L11.7,15.6 C11.7,16.3 10.9,16.6 10.4,16.2 L6.2,12.6 L3.2,12.6 C2.6,12.6 2.2,12.2 2.2,11.6 L2.2,8.4 C2.2,7.8 2.6,7.4 3.2,7.4 Z" fill="${colour}"/>
      ${muted
        ? `<g fill="none" stroke="${colour}" stroke-width="1.6" stroke-linecap="round"><path d="M13.6,7.6 L17.6,12.4 M17.6,7.6 L13.6,12.4"/></g>`
        : `<g fill="none" stroke="${colour}" stroke-width="1.6" stroke-linecap="round"><path d="M13.4,7.4 A4.2,4.2 0 0 1 13.4,12.6"/><path d="M15.9,5.2 A7.6,7.6 0 0 1 15.9,14.8"/></g>`}
    </g>`,
}

// ---------------------------------------------------------------- the window

/**
 * A window of the app, at the app's own sizes: the horizontal template at
 * 548 x 284, with the 52-point toolbar on top of it. Everything inside is the
 * number the app uses — the sleeve at 200, the 16-point air around it, the 26
 * point doors — and the whole group is then scaled onto the banner.
 */
/** The sleeve: a cover when there is one, the app's own pane when there is not. */
function coverBlock(x, y, size, withCover) {
  const r = 14
  if (!withCover) {
    const cx = x + size / 2
    const cy = y + size / 2
    const w = size * 0.42
    const h = size * 0.11
    const line = (() => {
      const pts = []
      for (let i = 0; i <= 64; i++) {
        const along = i / 64
        pts.push([cx - w / 2 + w * along, cy - Math.sin(along * 2 * Math.PI * 2) * h])
      }
      return 'M' + pts.map(([px, py]) => `${px.toFixed(2)},${py.toFixed(2)}`).join('L')
    })()
    return `<g>
      <rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${r}" fill="rgba(255,255,255,0.34)"/>
      <path d="${line}" fill="none" stroke="rgba(0,0,0,0.22)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
      <rect x="${x + 0.5}" y="${y + 0.5}" width="${size - 1}" height="${size - 1}" rx="${r}" fill="none" stroke="rgba(0,0,0,0.10)"/>
    </g>`
  }
  return `<g>
    <clipPath id="sleeveClip"><rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${r}"/></clipPath>
    <g clip-path="url(#sleeveClip)">
      <rect x="${x}" y="${y}" width="${size}" height="${size}" fill="#2B3138"/>
      <circle cx="${x + size / 2}" cy="${y + size * 0.42}" r="${size * 0.20}" fill="${TERRACOTTA}"/>
      <rect x="${x}" y="${y + size * 0.64}" width="${size}" height="${size * 0.36}" fill="${TERRACOTTA}"/>
      <g opacity="0.05">
        ${Array.from({ length: 140 }, (_, k) => {
          const gx = x + ((k * 37) % size)
          const gy = y + ((k * 91) % size)
          return `<rect x="${gx.toFixed(0)}" y="${gy.toFixed(0)}" width="1" height="1" fill="${k % 2 ? '#FFFFFF' : '#000000'}"/>`
        }).join('')}
      </g>
    </g>
    <rect x="${x + 0.5}" y="${y + 0.5}" width="${size - 1}" height="${size - 1}" rx="${r}" fill="none" stroke="rgba(0,0,0,0.10)"/>
  </g>`
}

function windowGroup({ x, y, scale, cover = true, sidebarOpen = false }) {
  const W = 548
  const H = 284
  const band = 52
  const pad = 16
  const art = 200
  const columnX = pad + art + 16
  const columnW = W - pad * 2 - art - 16
  const content = H - band
  const stack = 40 + 18 + 14 + 16 + 12 + 26 + 12 + 24
  const top = band + (content - stack) / 2
  const centre = columnX + columnW / 2
  const labelW = 38
  const barX = columnX + labelW + 8
  const barW = columnW - labelW * 2 - 16
  const filled = 0.39
  const door = 26
  const handsX = columnX + (columnW - (door * 3 + 12 * 2)) / 2
  const small = 22
  const volumeX = columnX
  const sliderX = columnX + (small + 8) * 3
  const sliderW = columnW - (small + 8) * 3

  const inner = `
    ${['#FF5F57', '#FEBC2E', '#28C840'].map((c, k) => `<circle cx="${20 + k * 20}" cy="26" r="6" fill="${c}"/>`).join('')}
    ${SYMBOLS.sidebar(84, 16, sidebarOpen ? '#16181C' : '#8E8B86')}
    ${SYMBOLS.folder(W - 76, 16, '#57565A')}
    ${SYMBOLS.sun(W - 46, 16, '#57565A')}
    <g transform="translate(0,0)">
      ${coverBlock(pad, band + (content - art) / 2, art, cover)}
      ${text('Полёт над городом', centre, top + 20, { size: 15, weight: 600, fill: '#16181C', anchor: 'middle' })}
      ${text('Аня Ветрова · Стекло', centre, top + 49, { size: 13, fill: '#6B6A69', anchor: 'middle' })}
      <g transform="translate(0,${top + 58 + 14})">
        ${text('1:38', columnX + labelW, 8, { size: 11, weight: 500, fill: '#9A9894', anchor: 'end' })}
        <rect x="${barX}" y="5.5" width="${barW}" height="5" rx="2.5" fill="rgba(0,0,0,0.10)"/>
        <rect x="${barX}" y="5.5" width="${(barW * filled).toFixed(1)}" height="5" rx="2.5" fill="#C1542B"/>
        ${text('-2:34', columnX + columnW - labelW, 8, { size: 11, weight: 500, fill: '#9A9894' })}
      </g>
      <g transform="translate(0,${top + 58 + 14 + 16 + 12})">
        ${SYMBOLS.back(handsX + 2, 4, '#8E8B86')}
        <rect x="${handsX + door + 12}" y="0" width="${door}" height="${door}" rx="8" fill="rgba(193,84,43,0.10)"/>
        ${SYMBOLS.pause(handsX + door + 12 + 8, 4, '#C1542B')}
        ${SYMBOLS.next(handsX + (door + 12) * 2 + 2, 4, '#8E8B86')}
      </g>
      <g transform="translate(0,${top + 58 + 14 + 16 + 12 + 26 + 12})">
        ${SYMBOLS.shuffle(volumeX, 2, '#8E8B86')}
        <rect x="${volumeX + small + 8}" y="-1" width="${small}" height="${small}" rx="8" fill="rgba(193,84,43,0.10)"/>
        ${SYMBOLS.repeat(volumeX + small + 8 + 6, 8, '#C1542B')}
        ${SYMBOLS.speaker(volumeX + (small + 8) * 2, 2, '#8E8B86')}
        <rect x="${sliderX}" y="${small / 2 - 1.5}" width="${sliderW}" height="3" rx="1.5" fill="rgba(0,0,0,0.10)"/>
        <rect x="${sliderX}" y="${small / 2 - 1.5}" width="${(sliderW * 0.72).toFixed(1)}" height="3" rx="1.5" fill="#C1542B"/>
        <circle cx="${(sliderX + sliderW * 0.72).toFixed(1)}" cy="${small / 2}" r="5" fill="#C1542B"/>
      </g>
    </g>`
  return `<g transform="translate(${x},${y}) scale(${scale})">
    <rect width="${W}" height="${H}" rx="10" fill="rgba(255,255,255,0.30)" filter="url(#windowBlur)"/>
    <rect width="${W}" height="${H}" rx="10" fill="url(#glassWash)"/>
    <rect width="${W}" height="${H}" rx="10" fill="url(#sheen)"/>
    <rect x="0.5" y="0.5" width="${W - 1}" height="${H - 1}" rx="10" fill="none" stroke="url(#rim)" stroke-width="1"/>
    ${inner}
  </g>`
}

// ---------------------------------------------------------------- header

export function headerSVG() {
  const W = 1280
  const H = 640
  const foot = H - 26
  const a = wave(0, foot, W * 2, 12, 3.5, 0)
  const b = wave(0, foot, W * 2, 12, 3.5, 0.12)
  const c = wave(0, foot, W * 2, 12, 3.5, 0.33)
  const fillA = a + ` L${W * 2},${H} L0,${H} Z`
  const mid = wave(0, H - 14, W * 2, 9, 4.5, 0.5)
  const mid2 = wave(0, H - 14, W * 2, 9, 4.5, 0.62)
  const mid3 = wave(0, H - 14, W * 2, 9, 4.5, 0.83)

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Dajet Player — Silence, playing. A quiet music player for macOS.">
  <defs>
    <radialGradient id="glowA" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="${TERRACOTTA}" stop-opacity="0.16"/>
      <stop offset="55%" stop-color="${TERRACOTTA}" stop-opacity="0.045"/>
      <stop offset="100%" stop-color="${TERRACOTTA}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowB" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0%" stop-color="${TERRACOTTA}" stop-opacity="0.10"/>
      <stop offset="100%" stop-color="${TERRACOTTA}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="glassWash" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.34"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.20"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.30"/>
      <stop offset="18%" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.55"/>
      <stop offset="50%" stop-color="#FFFFFF" stop-opacity="0.10"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.08"/>
    </linearGradient>
    <filter id="windowBlur" x="-25%" y="-25%" width="150%" height="150%">
      <feGaussianBlur stdDeviation="16"/>
    </filter>
    <filter id="soften" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="40"/>
    </filter>
    <clipPath id="frame"><rect width="${W}" height="${H}"/></clipPath>
  </defs>

  <g clip-path="url(#frame)">
    <rect width="${W}" height="${H}" fill="${GROUND}"/>
    <ellipse cx="1010" cy="250" rx="560" ry="420" fill="url(#glowA)"/>
    <ellipse cx="180" cy="620" rx="520" ry="360" fill="url(#glowB)"/>

    <!-- the desktop the window is glass over: two shapes out of focus, warm
         and cool, so that the glass has something to be glass over -->
    <g filter="url(#soften)" opacity="0.5">
      <ellipse cx="1010" cy="180" rx="280" ry="210" fill="#C08A5E"/>
      <ellipse cx="1210" cy="470" rx="240" ry="220" fill="#8E9AA4"/>
    </g>

    ${windowGroup({ x: 704, y: 186, scale: 0.86, cover: true })}

    <g>
      ${mark(96, 206, 112, { stroke: 66 })}
      ${text('Dajet Player', 96, 366, { size: 58, weight: 600 })}
      ${text('Тихий плеер для macOS', 96, 420, { size: 25, fill: SECONDARY })}
      ${text('Silence, playing.', 96, 486, { size: 16, weight: 500, fill: TERRACOTTA, tracking: 1.2 })}
    </g>

    <!-- the wave along the foot, at the series' own pace -->
    <g>
      <path fill="${TERRACOTTA}" fill-opacity="0.06" d="${fillA}">
        <animate attributeName="d" dur="9s" repeatCount="indefinite" calcMode="spline"
          keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
          values="${fillA};${fillA.replace(a, b)};${fillA}"/>
      </path>
      <path fill="none" stroke="${TERRACOTTA}" stroke-opacity="0.55" stroke-width="2" stroke-linecap="round" d="${a}">
        <animate attributeName="d" dur="9s" repeatCount="indefinite" calcMode="spline"
          keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
          values="${a};${b};${a}"/>
      </path>
      <path fill="none" stroke="${CREAM}" stroke-opacity="0.22" stroke-width="1.5" stroke-linecap="round" d="${mid}">
        <animate attributeName="d" dur="11s" repeatCount="indefinite" begin="-4s" calcMode="spline"
          keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
          values="${mid};${mid2};${mid}"/>
      </path>
      <path fill="none" stroke="${TERRACOTTA}" stroke-opacity="0.28" stroke-width="1.5" stroke-linecap="round" d="${c}">
        <animate attributeName="d" dur="13s" repeatCount="indefinite" begin="-7s" calcMode="spline"
          keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
          values="${c};${mid3.replace(/^M0/, 'M0')};${c}"/>
      </path>
    </g>
  </g>
</svg>
`
}

// ---------------------------------------------------------------- footer

export function footerSVG() {
  const W = 1200
  const H = 76
  const line = wave(0, 52, W * 2, 7, 6, 0)
  const line2 = wave(0, 52, W * 2, 7, 6, 0.16)
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Dajet Player is made by @bestdeejay-design.">
  <defs>
    <clipPath id="footerFrame"><rect width="${W}" height="${H}"/></clipPath>
  </defs>
  <g clip-path="url(#footerFrame)">
    <rect width="${W}" height="${H}" fill="${GROUND}"/>
    <path fill="none" stroke="${CREAM}" stroke-opacity="0.16" stroke-width="1.5" stroke-linecap="round" d="${wave(0, 62, W * 2, 6, 7, 0.35)}">
      <animate attributeName="d" dur="12s" repeatCount="indefinite" begin="-5s" calcMode="spline"
        keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
        values="${wave(0, 62, W * 2, 6, 7, 0.35)};${wave(0, 62, W * 2, 6, 7, 0.5)};${wave(0, 62, W * 2, 6, 7, 0.35)}"/>
    </path>
    <path fill="none" stroke="${TERRACOTTA}" stroke-opacity="0.8" stroke-width="2" stroke-linecap="round" d="${line}">
      <animate attributeName="d" dur="12s" repeatCount="indefinite" calcMode="spline"
        keyTimes="0;0.5;1" keySplines="0.45 0 0.55 1;0.45 0 0.55 1"
        values="${line};${line2};${line}"/>
    </path>
    ${text('Dajet Player', 40, 34, { size: 15, weight: 500, fill: CREAM })}
    ${text('@bestdeejay-design', W - 40, 34, { size: 15, weight: 500, fill: SECONDARY, anchor: 'end' })}
    ${text('MIT · free', W / 2, 34, { size: 14, fill: 'rgba(168,162,158,0.6)', anchor: 'middle' })}
  </g>
</svg>
`
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const out = process.argv[2] ?? path.resolve(import.meta.dirname, '..', 'assets')
  fs.mkdirSync(out, { recursive: true })
  fs.writeFileSync(path.join(out, 'header.svg'), headerSVG())
  fs.writeFileSync(path.join(out, 'footer.svg'), footerSVG())
  console.log('wrote', path.join(out, 'header.svg'), 'and', path.join(out, 'footer.svg'))
}
