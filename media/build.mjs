// Everything under assets/, made in one command.
//
//   npm install          (once: @napi-rs/canvas and sharp, the two tools that
//                         draw and encode; nothing here ships in the app)
//   node build.mjs       writes the icon, the five screenshots, the two social
//                        cards and the README's two banners into ../assets
//
// The order matters only in that the icon is written first: the banner, the
// cards and the screenshots each carry the same mark, and each draws it from
// the icon's own geometry rather than from a copy of the picture.

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

run('icon.mjs')      // assets/icon.svg, icon-1024.png, AppIcon.icns, icon-16x16-enlarged.png
run('screens.mjs')   // assets/screenshots/*.png
run('og.mjs')        // assets/og-player-1200.jpg, assets/og-player-1080.jpg
run('svg.mjs')       // assets/header.svg, assets/footer.svg

console.log('\nassets/ is written.')
