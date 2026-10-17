# media — where the pictures under `assets/` come from

Everything the player wears outside its own window is made here: the icon, the
five promo screenshots, the two social cards and the README's two banners. The
pictures are committed, so nothing here has to run for the repository to be
whole — this folder is how they were made, and how they are made again.

```bash
cd media
npm install        # @napi-rs/canvas and sharp, the two tools that draw
node build.mjs     # writes ../assets: icon, screenshots, cards, banners
```

Requires Node 20 or later. Neither dependency ships in the app: the app is
still SwiftUI, AVFoundation and nothing else, and the CI's zero-dependency
check is about the Swift package, not about a folder of picture makers.

## What is in here

| File | Writes | What it is |
|---|---|---|
| `icon.mjs` | `assets/icon.svg`, `assets/icon-1024.png`, `assets/AppIcon.icns`, `assets/icon-16x16-enlarged.png` | the mark: Apple's squircle filling the canvas, the series' near-black, one terracotta wave |
| `check-icns.mjs` | — | unpacks `AppIcon.icns` and verifies every entry has plate and mark pixels, and a plate that fills it |
| `screens.mjs` | `assets/screenshots/*.png` | the window, in its templates, at 2x |
| `og.mjs` | `assets/og-player-1200.jpg`, `assets/og-player-1080.jpg` | the two social cards |
| `svg.mjs` | `assets/header.svg`, `assets/footer.svg` | the README's banners, drawn as SVG so a README can be any width |
| `ui.mjs`, `kit.mjs` | — | the app's own widgets and colours, drawn from `Sources/DajetPlayer/Design.swift` |
| `fonts/` | — | Inter, subset to Latin and Cyrillic (OFL, see `fonts/OFL.txt`) |

## The two honest caveats

**The screenshots are drawn, not photographed.** This machine is not a Mac, so
there is no window to take a picture of. What `screens.mjs` does instead is
re-draw the window from the app's own source: the numbers are read out of
`Sources/DajetPlayer/Design.swift` (the palette, `Metrics`, the springs), the
rows and the frames out of `App.swift` and `Side.swift`. So the layouts, the
colours and the type sizes are the app's; what is *not* the app's is the sample
content — `Полёт над городом`, the playlists, the covers, the desktop behind
the glass. Those are placeholders, and are meant to be replaced by real
pictures from a Mac in a later pass (`node screens.mjs` will overwrite them,
one file per shot). This is said here rather than in a commit message because
somebody will one day want to know why a screenshot is a little too clean.

**Inter stands in for SF Pro.** SF Pro is Apple's and cannot be redistributed;
Inter is the closest face under the same licence the rest of the series is
under, and it carries Cyrillic — which matters, because the samples are in
Russian. In the app the font is the system's own (`Font.system`), so what the
screenshots show is what Inter looks like where SF Pro would be.

## The icon's numbers

The mark is the player's own wave (`Design.swift`, `Wave`): one sine, two
crests, stroked with round ends. On the icon it is drawn on the 1024 canvas of
macOS's icon grid with the body at 824 and the corner at `0.2253 × 824` — the
squircle is a superellipse, n = 5. The line is 74/1024, the same at every
entry: the SVG is rendered once at full resolution and downscaled with Lanczos
to each target size, so the small entries are a faithful shrink of the same
picture, not a redrawn one.

The `.icns` carries ten PNG entries — 16, 32, 128, 256, 512 and 1024 points at
one and two pixels per point — which is the grid Apple's own icons use, and it
is written by hand in `icon.mjs` rather than by `iconutil`, because `iconutil`
is macOS's and this folder runs anywhere. macOS 10.7 and later read PNG
entries; the old raw-bitmap types are for systems this app does not run on.

## The verification

`check-icns.mjs` unpacks the `.icns` by hand (no `iconutil` — runs on Linux
CI) and prints one line per entry: size, fraction of plate pixels (`#15181C`),
fraction of mark pixels (`#E8AE8C`), how far the plate reaches towards the
edges of the entry, and a pass/fail marker. An entry that comes out of the
build with zero plate and zero mark pixels — noise instead of a sign — makes
the script exit non-zero, so the defect that landed in PR #11 review (16×16 and
32×32 came out as coloured noise on a macOS build) cannot silently pass again.

The `edge` column is the same promise for the plate: it is the smallest share
of plate-coloured pixels along the middle half of the entry's four outer rows
and columns — `1.00` when the plate reaches every edge, `0.00` when there is a
clear margin around it. The icon that shipped before this change measured
`0.00` on all ten entries and now measures `1.00` on nine of them and `0.75` on
the 16 × 16 one, where a single pixel along the edge is half antialiasing. A
margin is a defect, not a style: macOS 26 draws a plate of its own behind an
icon that has one.

```bash
node media/check-icns.mjs                       # checks assets/AppIcon.icns
node media/check-icns.mjs path/to/icon.icns     # checks that file
```
