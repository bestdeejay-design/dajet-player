import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The window of the «dajet» version: a player, and a side menu.
//
// The main surface is the player itself and nothing else — the sleeve of what
// is playing, its name, and the transport under it. A list of the folder's
// tracks in the middle of the window was the first attempt at this version and
// the owner said no (P-06R): the tracks belong in the side menu, one folder at
// a time, where they are a list of *somewhere* rather than the window's whole
// subject. So the middle is the one track that matters, and the column is
// everything else.
//
// The side menu is the browser's own column: the same width, the same spring
// (Motion.glide), pulled out by a hand on the window's leading edge and sized
// by a hand on its own edge, with a toggle in the corner that is always there
// in both states. Inside it are playlists — folders of music, added by ⌘O or
// by being dropped on the window, kept until they are removed, and there for
// the next run (Playlists.swift, Side.swift).
//
// The look covers the whole window — glass in the light theme, matte
// almost-black in the dark — and the window itself is dressed for it
// (Window.swift, Design.swift).
//
// None of this touches what the player does. Space plays and pauses from the
// moment the window opens, with nothing clicked and nothing focused, the two
// arrows walk the queue beside it, the Mac's own media keys and its Now
// Playing card are the app's, volume and mute are remembered, and a folder
// dropped on the window plays at once — all of it the engine's, exactly as
// P-03 to P-05 left it.

@main
struct DajetPlayerApp: App {
    /// The player, made once for the life of the app.
    @StateObject private var engine = PlayerEngine()
    /// The playlists, and the file they live in — read before the window is,
    /// so that the menu opens with them already in it.
    @StateObject private var playlists = Playlists()

    init() {
        // The look that was chosen last time, put on the app before the window
        // is drawn: opening in the Mac's appearance and changing a moment
        // later is a window that looks like it fell over.
        let remembered = Theme.remembered
        DispatchQueue.main.async { remembered.apply() }
    }

    var body: some Scene {
        Window("Dajet Player", id: "player") {
            PlayerView(engine: engine, playlists: playlists)
                .frame(minWidth: 620, minHeight: 430)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 980, height: 640)
        // The one thing the menu bar has to offer that the window does not
        // already show all the time: a folder. ⌘O is the menu's and only the
        // menu's — a shortcut on a button that is not on screen is no shortcut
        // at all, and the side menu can be shut.
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Folder…") {
                    Chooser.folder(into: playlists, for: engine)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

/// The window, and everything in it.
struct PlayerView: View {
    @ObservedObject var engine: PlayerEngine
    @ObservedObject var playlists: Playlists

    /// The look that is on, kept between runs under the one key.
    @AppStorage(Theme.key) private var lookName = Theme.system.rawValue
    /// The side menu's width, remembered the same way.
    @AppStorage("sideWidth") private var sideSpan = Double(Metrics.side)
    /// Whether the side menu is out, and how far a hand has pulled it while
    /// one is on the window's edge.
    @State private var menu = false
    @State private var pull: CGFloat = 0
    /// A number that goes up when the menu's lists are out of date — it has
    /// just come out, or a folder has just been added.
    @State private var fresh = 0
    /// The key monitor that gives the window Space and the two arrows, for as
    /// long as it is open.
    @State private var keys: Any?
    /// Something is being dragged over the window, and the window says so
    /// while that lasts.
    @State private var taking = false
    /// Where a hand has the progress bar, in seconds into the track, while it
    /// is on it. Nothing at all when nobody is touching it — the bar then
    /// shows the player's own place, which is the whole point of it.
    @State private var scrubbing: TimeInterval?
    /// The pointer is on the bar.
    @State private var hoveringBar = false
    /// The pointer is on the play button.
    @State private var hoveringPlay = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The look, under everything: the whole window, the title bar's
            // band included.
            Surface()
            // The window itself, told what the surface is.
            WindowDress(glass: scheme == .light)
                .frame(width: 0, height: 0)

            // The player, in whatever is left of the window beside the menu —
            // and moving over as the menu comes out, on the menu's own spring,
            // so that the two are one gesture rather than two.
            player
                .padding(.leading, out)

            // The window's leading edge: a hand pulling the menu out.
            puller

            // The menu, over the player while it is on its way out and beside
            // it once it is there. It is never in the way of anything while it
            // is away: away means off the window's edge, where nothing can be
            // clicked, and not merely invisible.
            SideMenu(
                engine: engine,
                playlists: playlists,
                span: $sideSpan,
                refresh: fresh,
                close: { shut() },
                add: { Chooser.folder(into: playlists, for: engine) },
                drop: { accept($0) }
            )
            .offset(x: -span + out)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The window takes what the Finder can carry — a file, a folder, or a
        // handful of either — and nothing else: an address dragged in from a
        // browser is not a file URL, is not accepted, and never reaches the
        // player.
        .onDrop(of: [.fileURL], isTargeted: $taking) { take($0) }
        .overlay {
            if taking { dropHint }
        }
        .animation(Motion.quick, value: taking)
        .onAppear {
            // Again, in case the app was not there yet when it was asked for
            // the first time (see DajetPlayerApp's init).
            Theme.remembered.apply()
            watchKeys()
            // The reading of the files the menu is about to show, if any, is
            // as old as the last time it was out.
            fresh += 1
        }
        .onDisappear {
            if let keys { NSEvent.removeMonitor(keys) }
            keys = nil
        }
    }

    // MARK: - the shape of the window

    /// The width the menu occupies in the window: all of it while it is open,
    /// the hand's own worth while one is pulling it out, and nothing at all
    /// otherwise.
    private var out: CGFloat {
        menu ? span : min(max(pull, 0), span)
    }

    private var span: CGFloat {
        CGFloat(min(max(sideSpan, Double(Metrics.sideMin)), Double(Metrics.sideMax)))
    }

    private var look: Theme { Theme(rawValue: lookName) ?? .system }

    /// The menu comes out, or goes away, on the one spring — the width of the
    /// player, the column's own travel and the window's drop of it all in the
    /// same transaction, so nothing is ever a frame behind anything else.
    private func open() {
        fresh += 1
        withAnimation(Motion.glide) {
            menu = true
            pull = 0
        }
    }

    private func shut() {
        withAnimation(Motion.glide) {
            menu = false
            pull = 0
        }
    }

    /// The window's leading edge, while the menu is away: pull it to bring the
    /// column out. The hand's own travel is drawn as it moves and the spring
    /// only decides where it settles, which is what makes an edge feel like an
    /// edge rather than like a button.
    ///
    /// Below the top band, which belongs to the window's own drag, and only
    /// while the menu is away — an open menu has its own edge, and that one is
    /// for sizing it.
    private var puller: some View {
        Color.clear
            .frame(width: Metrics.pull)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding(.top, Metrics.bar)
            .allowsHitTesting(!menu)
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { hand in
                        guard !menu else { return }
                        pull = max(0, hand.translation.width)
                    }
                    .onEnded { hand in
                        guard !menu else { return }
                        let travelled = max(0, hand.translation.width)
                        // Either far enough to have meant it, or on its way
                        // there fast enough that letting go would be a lie.
                        let wanted = travelled > span * 0.34
                            || hand.predictedEndTranslation.width > span * 0.62
                        if wanted { open() } else { shut() }
                    }
            )
            .onHover { over in
                guard !menu else { return }
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .accessibilityHidden(true)
    }

    // MARK: - the player

    /// The player: the band, the one track that matters, and the transport.
    private var player: some View {
        VStack(spacing: 0) {
            helm
            Spacer(minLength: 12)
            middle
            Spacer(minLength: 12)
            foot
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The band along the top of the window: the menu's toggle in the corner
    /// beside the traffic lights — visible whether the menu is out or away,
    /// which is the whole of what a toggle has to be — and the two things a
    /// player can be told about itself at the other end. The rest of the band
    /// is the window's own: drag it to move the window, double-click it to
    /// fill the screen, drop a folder on it to play (see DragStrip).
    private var helm: some View {
        HStack(spacing: 4) {
            if !menu {
                // The traffic lights' corner, and then ours.
                Color.clear.frame(width: Metrics.lights)
                Door(
                    icon: "sidebar.leading",
                    help: "Show the side menu — playlists and their tracks   ⌥⌘S",
                    act: open
                )
            }
            Spacer(minLength: 0)
            Door(
                icon: "folder.badge.plus",
                help: "Add a folder of music — \(PlayerEngine.kinds)   ⌘O",
                act: { Chooser.folder(into: playlists, for: engine) }
            )
            Door(
                icon: look.icon,
                help: "\(look.title) — click for \(look.next.title)",
                act: walkLook
            )
        }
        .padding(.trailing, 16)
        .frame(height: Metrics.bar)
        .background(
            DragStrip(
                // Whatever is drawn in the band is its own: the runs the
                // buttons sit in are refused, and the click lands on them.
                leading: menu ? 0 : Metrics.lights + Metrics.door + 8,
                trailing: 16 + Metrics.door * 2 + 4,
                files: { accept($0) },
                targeted: { taking = $0 }
            )
        )
    }

    /// The middle of the window: what is playing, or the invitation to drop
    /// something on it, or whatever the player has to say instead of a track.
    @ViewBuilder
    private var middle: some View {
        if let track = engine.track {
            nowPlaying(track)
        } else if let note = engine.note {
            saying(note)
        } else {
            invitation
        }
    }

    /// What is playing: the sleeve, and the names on it. Nothing else — the
    /// list of the folder is in the menu, where it is a list of somewhere,
    /// and the window in front of the listener is the one track that is
    /// actually being heard.
    private func nowPlaying(_ track: URL) -> some View {
        VStack(spacing: 20) {
            Cover(cover: engine.cover)
            VStack(spacing: 5) {
                Text(engine.title ?? track.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(track.lastPathComponent)
                if let artist = engine.artist {
                    Text(artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 420)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
    }

    /// What is under the title: the album it came off, and where in the queue
    /// the player has got to. Both are optional and neither is a hole in the
    /// window when it is missing.
    private var caption: String {
        var said: [String] = []
        if let album = engine.album { said.append(album) }
        if engine.count > 0 { said.append("Track \(engine.number) of \(engine.count)") }
        return said.joined(separator: " · ")
    }

    /// Nothing has been opened, which is where a fresh copy of the player
    /// starts and where it stays: nothing is built in, and no folder plays
    /// itself (P-06R).
    private var invitation: some View {
        VStack(spacing: 16) {
            Wave(crests: 2, height: 0.34)
                .stroke(
                    Palette.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 92, height: 40)
            VStack(spacing: 5) {
                Text("Drop a folder of music, or a few files.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink)
                Text("\(PlayerEngine.kinds)  ·  ⌘O adds a folder to the menu")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
            }
        }
        .padding(.horizontal, 36)
    }

    /// The player has something to say that is not a track: nothing that was
    /// opened is music, or the queue has played itself out and the last of it
    /// is still there to be played again.
    private func saying(_ note: String) -> some View {
        VStack(spacing: 16) {
            Wave(crests: 2, height: 0.3)
                .stroke(
                    Palette.faint,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 76, height: 32)
            Text(note)
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
    }

    /// The foot of the window: how far into the track the player is and where
    /// a hand can take it to, then everything that can be pressed. All of it
    /// is the engine's — every button here is a hand on something the core
    /// already did in P-03 to P-05 — and only the drawing of it is this
    /// version's.
    private var foot: some View {
        VStack(spacing: 16) {
            progress
            transport
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
    }

    /// The line the track is drawn along, the two times at its ends, and the
    /// hand that can take it elsewhere.
    ///
    /// While a hand is on it the line follows the hand and the music does not
    /// move one bit: a drag that dragged the sound along would stutter the
    /// track through every place the thumb passed. Let go, and the track is
    /// taken to that place, playing or paused as it was — which is exactly
    /// what the bar at the foot of the window has always done.
    private var progress: some View {
        HStack(spacing: 12) {
            Text(clock(scrubbing ?? engine.position))
                .frame(width: 46, alignment: .trailing)
            GeometryReader { room in
                let wide = room.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.hairline)
                        .frame(height: line)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: wide * filled, height: line)
                    if drawn {
                        Circle()
                            .fill(Palette.accent)
                            .frame(width: 10, height: 10)
                            .offset(x: wide * filled - 5)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    }
                }
                .frame(width: wide, height: room.size.height, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(hold(along: wide))
            }
            .frame(height: 14)
            .onHover { over in
                withAnimation(Motion.quick) { hoveringBar = over }
            }
            Text(left)
                .frame(width: 46, alignment: .leading)
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.faint)
        // Nowhere to take the track and there is nothing to drag: a track
        // whose file has not said how long it is leaves the line drawn but
        // still, rather than one that jumps about over a length nobody knows.
        .opacity(scrubbable ? 1 : 0.4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((filled * 100).rounded())) percent")
    }

    /// The transport: the two modes and the volume either side of the three
    /// buttons that are always in the same place, which is where a hand
    /// expects them and where the browser's own toolbar keeps its buttons too.
    private var transport: some View {
        HStack(spacing: 16) {
            Door(
                icon: "shuffle",
                help: engine.shuffle
                    ? "Shuffled — click to walk the queue in the order it was opened"
                    : "In order — click to shuffle the queue",
                on: engine.shuffle,
                size: 30,
                glyph: 13,
                act: { engine.toggleShuffle() }
            )
            Door(
                icon: engine.repeatMode == .one ? "repeat.1" : "repeat",
                help: repeatHelp,
                on: engine.repeatMode != .off,
                size: 30,
                glyph: 13,
                act: { engine.cycleRepeat() }
            )

            Spacer(minLength: 18)

            Door(
                icon: "backward.fill",
                help: "Previous — the start of this track, once three seconds of it have gone by",
                size: 34,
                glyph: 15,
                enabled: engine.count > 0,
                act: { engine.previous() }
            )
            playButton
            Door(
                icon: "forward.fill",
                help: "Next track",
                size: 34,
                glyph: 15,
                enabled: engine.count > 0,
                act: { engine.next() }
            )

            Spacer(minLength: 18)

            Door(
                icon: engine.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                help: engine.muted ? "Muted — click to hear it again" : "Mute",
                on: engine.muted,
                size: 30,
                glyph: 12,
                act: { engine.toggleMute() }
            )
            Slider(value: loudness, in: 0...1)
                .frame(width: 66)
                .controlSize(.small)
                .tint(Palette.accent)
                .help("Volume — remembered between runs")
                .accessibilityLabel("Volume")
        }
    }

    /// Play, or pause: the one button in the window that is a shape rather
    /// than a glyph, and the one thing in it that is the accent all the way
    /// through. Nothing is playing and it says so by going quiet rather than
    /// by going away.
    private var playButton: some View {
        Button { engine.toggle() } label: {
            Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                // A play triangle is wider on one side than the other; a
                // single point of nudge puts it in the middle of the circle.
                .offset(x: engine.state == .playing ? 0 : 1.5)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Palette.accent))
                .contentShape(Circle())
                .scaleEffect(hoveringPlay ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .disabled(engine.count == 0)
        .opacity(engine.count == 0 ? 0.4 : 1)
        .onHover { over in
            withAnimation(Motion.quick) { hoveringPlay = over }
        }
        .help(engine.state == .playing ? "Pause (Space)" : "Play (Space)")
        .accessibilityLabel(engine.state == .playing ? "Pause" : "Play")
    }

    /// Something is being carried over the window: the whole of it says so,
    /// and says what will happen when it is let go.
    private var dropHint: some View {
        ZStack {
            Palette.accent.opacity(0.06)
            RoundedRectangle(cornerRadius: Metrics.panel + 3, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.55), lineWidth: 2)
                .padding(7)
            Text("Let go to play.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.panel, style: .continuous)
                        .fill(Palette.ground.opacity(0.82))
                )
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - the middle's own numbers

    /// How far into the track the line draws itself, from nought to one: where
    /// a hand has it while one is on it, and where the player is otherwise.
    private var filled: Double {
        let whole = engine.duration
        guard whole > 0 else { return 0 }
        return min(max((scrubbing ?? engine.position) / whole, 0), 1)
    }

    /// Whether there is anywhere on the line to take the track to: something
    /// playing or waiting, and a file that has said how long it is.
    private var scrubbable: Bool {
        engine.duration > 0 && engine.state != .idle
    }

    /// The line is thin and the place to take it by is not: the whole strip
    /// answers the drag, and the line — and the knob, while a hand is there —
    /// is drawn in it.
    private var line: CGFloat { drawn ? 6 : 4 }

    /// The knob is out while a hand is on the line or the pointer is over it,
    /// and is not drawn at all otherwise: a player that is not being touched
    /// has nothing to say about where the track is other than the line.
    private var drawn: Bool { hoveringBar || scrubbing != nil }

    /// The time at the other end: what is left of the track, said the way a
    /// player says it.
    private var left: String {
        guard engine.duration > 0 else { return "" }
        let left = engine.duration - (scrubbing ?? engine.position)
        return "-" + clock(left)
    }

    /// Seconds as a clock says them: minutes and seconds, with hours only when
    /// a file is long enough to need them.
    private func clock(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        let hours = whole / 3600
        let minutes = (whole % 3600) / 60
        let rest = whole % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// The hand on the line. Barely any movement is a drag as well — a
    /// `minimumDistance` of nothing — so that a click on the line is a click
    /// on a place in the track, which is what anyone clicking a line means.
    private func hold(along width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { hand in
                guard width > 0 else { return }
                scrubbing = seconds(at: hand.location.x, along: width)
            }
            .onEnded { hand in
                let landed = scrubbing ?? seconds(at: hand.location.x, along: width)
                scrubbing = nil
                engine.seek(to: landed)
            }
    }

    /// Where on the line a hand is, said in seconds into the track.
    private func seconds(at x: CGFloat, along width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return min(max(x / width, 0), 1) * engine.duration
    }

    /// The volume slider's two directions: where the player is, and where a
    /// hand dragging it asks the player to be. The engine owns the volume — it
    /// is the thing that is heard, and the thing that remembers.
    private var loudness: Binding<Float> {
        Binding(get: { engine.volume }, set: { engine.setVolume($0) })
    }

    /// What the repeat button says about itself, which is the three states it
    /// walks through put into words.
    private var repeatHelp: String {
        switch engine.repeatMode {
        case .off: return "Repeat off — the queue is walked once through"
        case .all: return "Repeat the queue — a new pass when one comes to an end"
        case .one: return "Repeat this track — until Next or Previous says otherwise"
        }
    }

    // MARK: - the looks

    /// Light, dark, or the Mac's own, walked round by the one button in the
    /// band. Three states on a button this small are only legible while it
    /// says which one it is in, so it wears the glyph of what is on and says
    /// the rest in its tooltip.
    private func walkLook() {
        let next = look.next
        lookName = next.rawValue
        next.apply()
    }

    // MARK: - the two ways in

    /// A drop from the Finder: one provider for each thing dropped, and each
    /// URL arrives a moment later, on a queue of its own. They are collected
    /// in the order they were dropped — a queue that plays out of order is not
    /// the queue that was dropped — and handed to the player together.
    private func take(_ providers: [NSItemProvider]) -> Bool {
        let carriers = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !carriers.isEmpty else { return false }
        let found = Handful(of: carriers.count)
        let whole = DispatchGroup()
        for (place, carrier) in carriers.enumerated() {
            whole.enter()
            carrier.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { whole.leave() }
                guard let url = Handful.url(item) else { return }
                found.keep(url, at: place)
            }
        }
        // The player itself, held for the moment the answers come back: this
        // view may not be the one on screen by then.
        let engine = engine
        let playlists = playlists
        whole.notify(queue: .main) {
            MainActor.assumeIsolated { accept(found.urls, into: playlists, playing: engine) }
        }
        return true
    }

    /// What was dropped, wherever it was dropped: a folder joins the menu and
    /// everything dropped becomes the queue and plays, which is what dropping
    /// music on this player has always done and is not this wave's to change.
    /// Only folders are remembered — a handful of loose files is a queue and
    /// not a place, and the menu is a list of places.
    private func accept(_ urls: [URL]) {
        accept(urls, into: playlists, playing: engine)
    }

    private func accept(_ urls: [URL], into playlists: Playlists, playing engine: PlayerEngine) {
        guard !urls.isEmpty else { return }
        for url in urls where isFolder(url) {
            playlists.add(url)
        }
        fresh += 1
        engine.open(urls)
    }

    /// Whether this is a folder: only a folder can be a playlist.
    private func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    // MARK: - the keyboard

    /// The keys the player takes from the keyboard — Space and the two arrows
    /// — anywhere in the window, from the moment it opens: nothing has to be
    /// clicked, and nothing has to have the keyboard for it. A view that asked
    /// SwiftUI for a key would be given it only while it was focused, and
    /// these are the keys a player has to hear whatever else is going on. A
    /// local monitor hears them before anything else in this app does and
    /// swallows them — so the button that happens to be focused isn't pressed
    /// along with them, and nothing beeps.
    ///
    /// The keys are told apart by their code rather than by the characters
    /// they would have made, because these three are places on the keyboard
    /// and not letters. Up and down are left alone — they are the system's,
    /// and this app has nothing to say about them. The Mac's own media keys
    /// are not here and never will be: the system hands those to the app
    /// through `MPRemoteCommandCenter` (the engine's business), and a second
    /// monitor listening for them would be a second way to play the same
    /// thing.
    ///
    /// One thing here is not a key of the player's own: ⌥⌘S, which is the side
    /// menu — the browser's own shortcut for its column, and the reason it is
    /// in the key monitor rather than on a button is that the toggle is not
    /// always on screen.
    private func watchKeys() {
        guard keys == nil else { return }
        let engine = engine
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Nothing here is a key in the folder panel: that panel is this
            // app's too, and its keys are its own.
            guard !(event.window is NSPanel) else { return event }
            // The side menu's own shortcut, before the rule that throws
            // modified keys away.
            let menuKeys: NSEvent.ModifierFlags = [.command, .option]
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == menuKeys,
               event.charactersIgnoringModifiers?.lowercased() == "s" {
                MainActor.assumeIsolated {
                    if menu { shut() } else { open() }
                }
                return nil
            }
            // Bare keys, and one press at a time: a modifier makes a key into
            // another key entirely, and a held key repeats — a player walked
            // by a held arrow would fly through the queue as fast as the
            // keyboard could say so, and a held space would start and stop the
            // music just as fast.
            let borrowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.modifierFlags.isDisjoint(with: borrowed), !event.isARepeat else {
                return event
            }
            switch event.keyCode {
            case 49:    // space, the one key a player cannot do without
                MainActor.assumeIsolated { engine.toggle() }
                return nil
            case 123:   // left: this track again, or the one before it
                MainActor.assumeIsolated { engine.previous() }
                return nil
            case 124:   // right: the next track
                MainActor.assumeIsolated { engine.next() }
                return nil
            default:
                return event
            }
        }
    }
}

/// The sleeve of what is playing: the cover as it is, sharp, in a square cut
/// with the window's own continuous corner. A file with no cover is not a hole
/// in the window — the player's own wave stands where the picture would be, on
/// a pane so faint that it is a pane and not a grey rectangle pretending to be
/// an album.
///
/// Its size follows the window, within reason: the largest square the middle
/// of the window can hold, never larger than the metric, so that a large
/// window gets a large sleeve and a small one still gets the whole player.
private struct Cover: View {
    let cover: NSImage?

    var body: some View {
        GeometryReader { room in
            let side = min(Metrics.sleeve, min(room.size.width, room.size.height))
            ZStack {
                if let cover {
                    Image(nsImage: cover)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else {
                    Palette.pane
                    Wave(crests: 2, height: 0.3)
                        .stroke(
                            Palette.faint,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: side * 0.42, height: side * 0.22)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.panel + 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.panel + 2, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 22, y: 12)
            .frame(width: room.size.width, height: room.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// What the providers of one drop turned up, in the order they were dropped.
///
/// Each answer comes back on a queue of its own — an item provider hands its
/// URL over whenever it is ready — so the answers are put in their place
/// behind a lock rather than trusting any of them to arrive first.
private final class Handful: @unchecked Sendable {
    private let lock = NSLock()
    private var found: [URL?]

    init(of count: Int) {
        found = Array(repeating: nil, count: count)
    }

    func keep(_ url: URL, at place: Int) {
        lock.lock()
        defer { lock.unlock() }
        found[place] = url
    }

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return found.compactMap { $0 }
    }

    /// The file a provider was carrying: a URL when it hands one over, the
    /// bytes of one when it hands those over instead. Which of the two turns
    /// up depends on where the drag began, and they are the same thing written
    /// differently.
    static func url(_ item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }
}
