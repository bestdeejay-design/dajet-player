# Changelog

What changes in Dajet Player from one version to the next, newest first.

**Unreleased** gathers what is done since the last version, as it lands: every
addition gets its line the day it is merged. When a version ships, the section
takes its number and date, its gist becomes the paragraph in `NOTES.md` (what a
later wave's updater and What's New card read), and the list is what gets
posted as the update. What is planned but not done yet lives in
[ROADMAP.md](ROADMAP.md).

## Unreleased

Nothing yet. Playback is the next wave (P-03…P-05).

## 0.1.0 — 2026-10-12

The skeleton: the project builds, and what it builds opens as an ordinary Mac
app with one empty window. Nothing plays, and nothing reaches the network.

### Added

- `Package.swift` — one SwiftPM executable target, `DajetPlayer`, on macOS 14
  and later: swift-tools 6.0, language mode 5, and no dependencies at all
- `Sources/DajetPlayer/App.swift` — one window, and nothing else: no toolbar,
  no sidebar, the title bar hidden
- `build.sh` — one command: a release build, and a `build/DajetPlayer.app`
  around the binary — `ru.dajet.player`, `LSMinimumSystemVersion` 14.0, the
  version read from `VERSION`, ad-hoc signed, with a dSYM left beside it
- The shape of `dajet-browser`, kept as it is: `VERSION`, `LICENSE` (MIT),
  `.gitignore`, `README.md`, `README.ru.md`, `NOTES.md`, `ROADMAP.md`,
  `assets/`

### Not yet

- Playback, metadata, cover art, media keys (P-03…P-05)
- Both skins, the equalizer, the disk image, the ZIP, the appcast and the
  Homebrew tap (P-06…P-09)
