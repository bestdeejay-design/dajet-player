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
app's own file, and still there the next time it opens. The player now lives
in the tray as well: an icon of its own in the menu bar, a full menu under it
(the current track and where it sits, play/pause/previous/next, the playlists
each with their own lazy submenu of tracks, Open Folder…, the theme, settings,
Show and Quit), and the icon moving while music plays. Covers are read from
the file's own tags when it has them and from a picture beside it when it
does not. The window will not shrink below a formal square of 232 points
(plus the toolbar), and the toolbar itself is the system's own. Still only
Apple's frameworks and this Mac, with nothing third-party. On top of that,
the window now knows its shape: two templates the owner measured — Horizontal
548×284 and Vertical 232×441 — and a Custom that is whatever the hand left it
as, with no snap back. Appearance is three presets in the tray (Aero, Obsidian,
System); the same preset keeps a chosen template, a different one restores its
default. Clicking the tray icon hides the window and shows it again; the menu
has Shuffle, Repeat, a Volume submenu and a quiet progress read-out. The light
glass is clearer, the column is almost opaque, and the tray icon moves at four
small steps a second.

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
- `Sources/DajetPlayer/Tray.swift` — the player in the menu bar: an
  `NSStatusItem` with a template icon drawn in code, a menu rebuilt each time
  it is asked for (the current track and where it sits in the pass,
  play/pause/previous/next, the playlists with a lazy submenu of tracks under
  each, Open Folder…, the theme, settings — hide the Dock icon, animate the
  tray icon while playing — and Show / Quit), and the icon moving at nine
  frames a second only while music plays. The tray owns the engine and the
  playlists, so the music outlives the window
- `Sources/DajetPlayer/Artwork.swift` — covers from three places, in order:
  the file's own tags through AVFoundation, the raw bytes of an ID3v2 or
  FLAC picture, and a file of the same name beside the track (`folder.jpg`,
  `cover.jpg`, `front.jpg`, `album.jpg` and the like). Cached by modification
  time so a cover is read once, and kept alive as long as the window wants it
- `Sources/DajetPlayer/App.swift` — the system's own toolbar: the side menu's
  toggle at the leading end beside the traffic lights (⌥⌘S), Open Folder… and
  the theme at the trailing end. The old band of icons in the window's body
  is gone; the toolbar is the only place those three live now
- `Sources/DajetPlayer/App.swift` — the window will not shrink below a formal
  square of 232 points of content (232×284 with the toolbar), and when it is
  that narrow the side menu comes out over the player rather than pushing it
  aside; the column never slides past the window's leading edge
- `Sources/DajetPlayer/Presentation.swift` — window templates (Horizontal
  548×284, Vertical 232×441, Custom with no snap), appearance presets (Aero /
  Obsidian / System), the shared side column state, and the migration that
  leaves an existing install's look and frame alone while a clean install opens
  Aero + Vertical with the column shut
- `Tests/DajetPlayerTests/PresentationTests.swift` — regression tests for the
  migration, the appearance reset matrix, the owner's frame sizes, persistence
  and frame application (Custom on manual resize, reopen, same-appearance
  restore)
- `.github/workflows/build.yml` — continuous integration on macOS 15 with
  Swift 6.1.2 and Xcode 16.4: a debug build, a release build and `./build.sh`,
  with the compiler's own lines attached to the pull request as annotations
  and a notice naming the toolchain and the weight of the bundle; `swift test`
  runs with them

### Changed

- `Sources/DajetPlayer/App.swift` — the window no longer draws a blurred cover
  behind itself: the surface of the window is the look now (glass or matte),
  and the cover is drawn once, sharp, as the sleeve of what is playing. The
  engine still publishes the blurred `artwork` and draws it nowhere in this
  version; the same picture is published as `cover` for the sleeve
- `Sources/DajetPlayer/Window.swift` — the light glass is clearer: the system
  material at 0.78 density, a short sheen at the top instead of a full-height
  wash, lighter lift and foot, and a one-point rim so the pane has an edge on
  a bright desktop; Reduce Transparency falls back to the solid ground
- `Sources/DajetPlayer/Design.swift` — the side column is almost opaque (a
  near-solid tile in both themes) so its text reads over the player, with the
  opaque ground when Reduce Transparency is on
- `Sources/DajetPlayer/Tray.swift` — the tray icon's dance is calmer: four
  frames a second, eight small steps, one bar moving at a time between 0.45
  and 0.70 instead of all four jumping; the Show item hides a visible window
  (`orderOut`) and shows a hidden one; the menu gains Window templates,
  Appearance presets, a Side Menu toggle, Shuffle / Repeat / Volume quick
  controls and a quiet `position / duration · %` line; clicking the current
  track always shows the window

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
