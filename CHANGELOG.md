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
another, with its title, artist and album from the file, and its cover in the
window when it has one. Next, Previous, shuffle and repeat for the queue;
Space still plays and pauses, the two arrows walk the queue beside it, and the
Mac's own media keys and Now Playing card are the app's as well. A thin bar
along the foot of the window shows how far into the track the player is, and
takes it to another place when dragged; a volume slider and a mute button sit
in the bar, and both are remembered between runs. The window itself now wears
the `dajet` version of the look — glass over the whole of its surface in the
light theme, matte near-black in the dark — with a side menu of playlists
beside it: folders added by ⌘O or by being dropped on the window, kept in the
app's own file, and still there the next time it opens. Still only Apple's
frameworks and this Mac, with nothing third-party.

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
- `Sources/DajetPlayer/PlayerEngine.swift` — the Mac's own controls, all of
  them hands on the buttons that were already there: the media keys (play,
  pause, play/pause, next and previous) through `MPRemoteCommandCenter`, with
  `.success` and `.commandFailed` answered honestly — play and pause ask for a
  state rather than for a change, so a play key never pauses; the Now Playing
  card in Control Center and on the lock screen through `MPNowPlayingInfoCenter`
  — title (the filename when the file gave none), artist, duration, elapsed
  time, playback rate and the cover, taken down whenever nothing is playing;
  position and duration published for the progress bar, and `seek(to:)` behind
  it (the very end included: the track is taken there and plays itself out, so
  the queue's own rules decide what follows); volume and mute, saved in
  `UserDefaults` and put back into the player before the first track of the
  next run
- `Sources/DajetPlayer/App.swift` — the thin progress bar along the foot of the
  window: no numbers, the line is the whole of what it says, a drag moves the
  line and not the music, and the track is taken to the place the hand lets go
  of; a volume slider and a mute button in the bar (both remembered between
  runs), and the `←` / `→` keys added to the key monitor that already had Space

- `Sources/DajetPlayer/Design.swift` — the foundations of the look: one
  palette of paired light/dark colours (the series' terracotta for the accent,
  and a near-black for the dark window's ground — the series' own dark plate is
  a page underlay, and a whole window of it reads grey), the distances the
  window is laid out by, the two springs everything moves on, and the two
  accessibility settings that take them away
- `Sources/DajetPlayer/Window.swift` — the surface over the whole window, and
  the window dressed for it: a system material behind the window with the lift,
  the sheen and the foot that make a pane read as a pane, a transparent title
  bar, and a `DragStrip` along the band that drags the window, answers the
  double-click and takes a folder dropped on it
- `Sources/DajetPlayer/Side.swift` — the side menu: the browser's own column
  (232 points resting, pulled between 176 and 440 by its own edge, in and out
  on one spring), a visible toggle in the window's top-left corner, playlists
  with their tracks under them, the folder being played and the track being
  heard both marked, and a click on a track that plays it at once
- `Sources/DajetPlayer/Playlists.swift` — playlists as folders, in a `Codable`
  file of the app's own (`~/Library/Application Support/Dajet Player/playlists.json`,
  written off the main thread and atomically): added by ⌘O or by drop, removed
  by hand and only by hand
- `Sources/DajetPlayer/PlayerEngine.swift` — `source` (the folder the queue
  came from, for the menu to mark), `cover` (the cover as it is, for the
  window's sleeve) and `play(_:in:)`: one track of a playlist, played now, on
  the queue of the folder that is already playing rather than by opening the
  folder again
- `Sources/DajetPlayer/App.swift` — the main window as a player and not a
  list: the sleeve of what is playing, its name and artist, the transport
  beneath it, and the tracks of a folder in the side menu, where they belong

### Changed

- `Sources/DajetPlayer/App.swift` — the window no longer draws a blurred cover
  behind itself: the surface of the window is the look now (glass or matte),
  and the cover is drawn once, sharp, as the sleeve of what is playing. The
  engine still publishes the blurred `artwork` and draws it nowhere in this
  version; the same picture is published as `cover` for the sleeve

### Not yet

- The `joer` version's five atmospheres, the equalizer, the disk image, the
  ZIP, the appcast and the Homebrew tap (P-07…P-09)

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
