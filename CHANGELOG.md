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
another, with its title, artist and album from the file, and its cover behind
the window when it has one. Next, Previous, shuffle and repeat for the queue;
Space still plays and pauses. Still only Apple's frameworks and this Mac,
with nothing third-party.

### Added

- `Sources/DajetPlayer/PlayerEngine.swift` — the queue and the one AVPlayer
  behind it: mp3, m4a (AAC), flac, wav and aiff (and `.aif`), a folder read for
  the music in it, its files sorted the way the Finder sorts them ("Track 2"
  before "Track 10"), the next track as each one ends, and `idle` / `playing` /
  `paused`. Next and Previous walk the pass; Fisher–Yates shuffles a separate
  list of queue places without rewriting the queue; repeat cycles through off,
  all and one. Local title, artist, album and artwork are read asynchronously
  from the file and the names are cached. A file that will not open is passed
  over, and when nothing that was opened plays, the player says so rather than
  sitting silent
- `Sources/DajetPlayer/App.swift` — the window that takes the drop (files and
  folders, anywhere in it), buttons for Previous, Next, play/pause and Open
  Folder… (which carries ⌘O), shuffle and repeat controls, and a line saying
  what is playing and where it sits in the pass. A local cover is blurred once
  off the main thread and fades in behind the contents; no cover leaves the
  plain dark underlay showing. Space is still wired to play and pause from
  the moment the window opens: a key monitor, so nothing has to be clicked or
  focused first
- Every track played is a `file://` URL on this Mac, and all the names and
  pictures are read from that file — nothing here will take an address that
  could be somewhere else. "No network requests" is a property of the code,
  not only of the intent

### Not yet

- The `←` / `→` shortcuts named in the acceptance criteria for P-04. They were
  left out pending the coordinator's decision on whether they belong in this
  wave; the Previous and Next buttons are present
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
