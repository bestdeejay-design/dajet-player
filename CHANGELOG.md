# Changelog

What changes in Dajet Player from one version to the next, newest first.

**Unreleased** gathers what is done since the last version, as it lands: every
addition gets its line the day it is merged. When a version ships, the section
takes its number and date, its gist becomes the paragraph in `NOTES.md` (what a
later wave's updater and What's New card read), and the list is what gets
posted as the update. What is planned but not done yet lives in
[ROADMAP.md](ROADMAP.md).

## Unreleased

Opening music and playing it: a folder, a file, or a handful of either, dropped
on the window or chosen from Open Folder… — played in order, one track after
another, with Space for play and pause. Still nothing in the app but SwiftUI,
AVFoundation and this Mac.

### Added

- `Sources/DajetPlayer/PlayerEngine.swift` — the queue and the one AVPlayer
  behind it: mp3, m4a (AAC), flac, wav and aiff (and `.aif`), a folder read for
  the music in it, its files sorted the way the Finder sorts them ("Track 2"
  before "Track 10"), the next track as each one ends, and `idle` / `playing` /
  `paused`. A file that will not open is passed over, and when nothing that was
  opened plays, the player says so rather than sitting silent
- `Sources/DajetPlayer/App.swift` — the window that takes the drop (files and
  folders, anywhere in it), two buttons — play/pause and Open Folder…, which
  carries ⌘O — a line saying what is playing and where it sits in what was
  opened, and Space wired to play and pause from the moment the window opens:
  a key monitor, so nothing has to be clicked or focused first
- Every track played is a `file://` URL on this Mac, and nothing here will
  take an address that could be somewhere else — "no network requests" is now
  a property of the code, not only of the intent

### Not yet

- Title, artist and cover art, Next/Previous, shuffle and repeat (P-04)
- The keyboard's media keys, progress, scrubbing and volume (P-05)
- Both skins, the equalizer, the disk image, the ZIP, the appcast and the
  Homebrew tap (P-06…P-09)

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
