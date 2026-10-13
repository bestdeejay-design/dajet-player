<picture><img src="assets/header.svg" alt="Dajet Player"></picture>

# Dajet Player

**Silence, playing.** — a quiet music player for macOS. Native Swift · MIT · free.

Open Dajet Player. Drop a folder of music on it — it plays, in the order the Finder lists it. That is all there is to it, for now.

**🌐 Versions:** [English](README.md) · [Русский](README.ru.md)

## Where it is

**v0.3.0 — the Mac's own controls are its own.** The project builds with SwiftPM and `./build.sh`, and what they make opens as an ordinary Mac app: one window, no toolbar, no sidebar; a line saying what is playing, Previous and Next, play/pause and Open Folder…, shuffle and repeat, a thin progress bar, a volume slider and a mute button. Drop a folder of music — or a few files, mp3, m4a, flac, wav, aiff — and it plays them one after another, its title, artist and album read from the file, its cover on the window; a file that will not open is passed over, and the player says so when nothing plays at all. Space stops it and starts it again, the `←` and `→` keys walk the queue, the keyboard's media keys and the Now Playing card in Control Center are the app's own, and at the end of a pass it starts from the top. Volume and mute are remembered between runs.

The look of that window is now the `dajet` version of it: glass over the whole of its surface in the light theme, matte near-black in the dark, and a side menu that comes out of the window's leading edge on one spring. Inside it are the playlists — folders, added by ⌘O or by being dropped on the window, each one staying in the menu with its tracks under it until it is removed, and still there the next time the player opens. The main window stays a player: the sleeve of what is playing, its name, and the transport beneath it.

The `joer` skin and the release are the waves that follow; the queue is in [ROADMAP.md](ROADMAP.md).

## What it is

Dajet Player holds the position the rest of the series does: **a player that stays silent**.

Launch it, open Network Monitor — zero connections. Nothing leaves the machine, and nothing in the app is built to leave it: no telemetry, no accounts, no cloud, no cover art fetched from somewhere, no update check you didn't ask for. Not a promise: a verifiable claim, part of the release checklist.

- SwiftUI and AVFoundation, and nothing else — no third-party dependencies
- macOS 14 and later, Apple Silicon first
- One playback core, two skins: `dajet` (dark and light, glass — this wave) and `joer` (the five atmospheres of [joer.ru](https://joer.ru), to come)

## What it can

**P-06R — the look, and the menu beside it.** The window is glass over the whole of its surface in the light theme — the desktop behind it, blurred, with the lift and the sheen that make a pane read as one — and matte near-black in the dark, with nothing of the desktop in it. The light or the dark is one button in the window's corner, or the Mac's own choice; with Reduce Transparency on, the glass is drawn as a solid pale surface instead. A side menu slides out of the window's leading edge on the spring the browser next door uses: pull the edge to bring it out, drag its own edge to size it, press the toggle in the top-left corner to send it away. In it are playlists — folders of music, added by ⌘O or by drop, kept in the app's own file in `~/Library/Application Support/Dajet Player/`, removed by hand and only by hand. A folder's tracks are under its name in the menu; click one and it plays, on that folder's queue, with the one being heard marked — and never a wall of rows in the middle of the window, which is the player's and stays the player's.

**P-05 — the system's own controls.** The keyboard media keys are the app's: play, pause, play/pause, next and previous, each one a hand on a button that was already there — play never pauses, pause never starts. The Now Playing card in Control Center and on the lock screen carries the title, artist, duration and progress, and goes away when nothing plays. A thin bar along the foot of the window shows where the track is; dragging it moves the line and not the music, and the track is taken where the hand lets go — even into its very end, which plays itself out by the queue's rules. Volume and mute, remembered between runs. `←` and `→` walk the queue beside Space.

**P-04 — knows what it plays.** Title, artist and album read from the file, a local cover drawn sharp in the middle of the window (the blurred backdrop it faded into was the version before this one: the window is the look now), Next and Previous (Previous restarting a track once its three seconds have gone, otherwise stepping back; on the first track it restarts), shuffle that never repeats a track twice in a pass, and repeat cycling through off, all and one. A file that will not open is passed over, and when nothing that was opened plays, the player says so. What is coming, in order:

- **after that** — the `joer` skin, the equalizer, the disk image and the Homebrew tap (P-07…P-09)

## Privacy

| What | Where | Who can read |
|---|---|---|
| Your music | where it already is — never copied, never uploaded | you |
| What the player keeps, from wave 2 on | `~/Library/Application Support/Dajet Player/` | you |
| Everything else | nowhere | — |

## Build from source

```bash
git clone https://github.com/bestdeejay-design/dajet-player
cd dajet-player
./build.sh
```

`build/DajetPlayer.app` — double-click it, or `open build/DajetPlayer.app`. Needs Swift 6 (Xcode command line tools) and macOS 14 or later.

`swift build` on its own gives the plain binary; `./build.sh` is the one that wraps it in the app.

## License

MIT — [LICENSE](LICENSE). Development: [bestdeejay-design/dajet-player](https://github.com/bestdeejay-design/dajet-player).

---

<picture><img src="assets/footer.svg" alt=""></picture>

*Dajet Player is the second app of the [Dajet](https://github.com/bestdeejay-design/dajet-browser) series: the browser came first, the player follows the same quiet rules.*
