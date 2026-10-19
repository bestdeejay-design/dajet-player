// The pictures under assets/, made in one command.
//
//   npm install          (once: @napi-rs/canvas and sharp, the two tools that
//                         draw and encode; nothing here ships in the app)
//   node build.mjs       writes the five screenshots, the two social cards and
//                        the README's two banners into ../assets
//
// The icon is not here. It is drawn by Icon/icon.swift (the canon, in Swift,
// generated at build time — no image asset in the repository), and build.sh
// puts it into the app. What these generators share with it is the geometry in
// mark.mjs, so the banners and the cards carry the same mark the app wears.

import { execFileSync } from 'node:child_process'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const assets = path.resolve(here, '..', 'assets')

fs.mkdirSync(path.join(assets, 'screenshots'), { recursive: true })

const run = (file) => {
  console.log(`\n── ${file}`)
  execFileSync(process.execPath, [path.join(here, file), assets], { stdio: 'inherit', cwd: here })
}

run('screens.mjs')   // assets/screenshots/*.png
run('og.mjs')        // assets/og-player-1200.jpg, assets/og-player-1080.jpg
run('svg.mjs')       // assets/header.svg, assets/footer.svg

console.log('\nassets/ is written.')
