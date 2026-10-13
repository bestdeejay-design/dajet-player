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
// Along the top of the window there is a toolbar, and it is the system's own
// (P-10): the side menu's toggle at the leading end beside the traffic lights,
// and the two things a player can be told about itself — a folder, and which
// of the three looks it wears — at the other. A band drawn by hand was what
// this window had before, and a hand-drawn band is a band that has to guess
// where the traffic lights are, put window dragging back by hand, and answer a
// double-click on a title bar it does not have; a toolbar is given all three by
// the platform, in the place macOS puts them, and it costs nothing in the
// window's body. Nothing else in the body is a button that belongs at the top.
//
// The side menu is the browser's own column: the same width, the same spring
// (Motion.glide), pulled out by a hand on the window's leading edge and sized
// by a hand on its own edge, with the toolbar's toggle there in both states.
// Inside it are playlists — folders of music, added by ⌘O or by being dropped
// on the window, kept until they are removed, and there for the next run
// (Playlists.swift, Side.swift). The column is never wider than the window it
// is in and never shoves the player out of it: on a window too narrow for both,
// the column goes *over* the player, which is what a drawer does, rather than
// squeezing the transport until it runs off the edge (P-10 — the layout the
// owner sent a picture of).
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
// P-03 to P-05 left it. And the player is not the window's any more: the tray
// owns it, so closing the window leaves the music playing and the menu bar in
// charge of it (Tray.swift).

@main
struct DajetPlayerApp: App {
    /// The tray: the app's own delegate, and the thing that owns the player and
    /// the playlists for as long as the app runs. Owned there rather than here
    /// because a window can be closed and the player cannot — the music goes on
    /// with no window at all, and the menu bar is where it is answered for.
    @NSApplicationDelegateAdaptor(Tray.self) private var tray

    init() {
        // The look that was chosen last time, put on the app before the window
        // is drawn: opening in the Mac's appearance and changing a moment
        // later is a window that looks like it fell over.
        let remembered = Theme.remembered
        DispatchQueue.main.async { remembered.apply() }
    }

    var body: some Scene {
        Window("Dajet Player", id: PlayerView.windowID) {
            PlayerView(engine: tray.engine, playlists: tray.playlists)
                // A formal square, and the column's own resting width: the
                // window is never smaller than the side menu is wide, and never
                // narrower than it is tall (P-10). What the player needs to be
                // comfortable is more than this, and a window resized down to
                // here is a window with a drawer over it rather than one with
                // its transport hanging off the edge.
                .frame(minWidth: Metrics.side, minHeight: Metrics.side)
        }
        // The system's own toolbar, with no title in it: the buttons are the
        // window's, the traffic lights are macOS's, and the band they share is
        // transparent, so the glass underneath is the glass of the whole window
        // rather than of everything below a bar (see Window.swift).
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 560, height: 420)
        // The one thing the menu bar has to offer that the window does not
        // already show all the time: a folder. ⌘O is the menu's and only the
        // menu's — a shortcut on a button that is not on screen is no shortcut
        // at all, and the side menu can be shut.
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Folder…") {
                    Chooser.folder(into: tray.playlists, for: tray.engine)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

/// The window, and everything in it.
struct PlayerView: View {
    /// The id the scene keeps this window under, and the tray looks it up by
    /// when it is asked to bring the player back.
    static let windowID = "player"

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
    /// SwiftUI's own way of asking for this window back, which is what the tray
    /// does when the window has been closed and there is nothing among the
    /// app's windows to bring forward.
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The look, under everything: the whole window, the toolbar's band
            // included.
            Surface()
            // The window itself, told what the surface is.
            WindowDress(glass: scheme == .light)
                .frame(width: 0, height: 0)

            // Everything else, laid out against the room the window actually
            // has — which is the room below the toolbar, and is asked of the
            // layout rather than assumed, because a window that can be resized
            // down to a square of 232 points is a window whose contents have to
            // know how narrow they are.
            GeometryReader { room in
                let wide = room.size.width
                // The column is never wider than the window it is in.
                let column = min(span, max(0, wide))
                // How far the player may be shoved over: far enough for the
                // column, and never so far that there is no player left. A
                // window too narrow for both gets the column *over* the player,
                // which is what a drawer does, instead of a transport squeezed
                // until it runs off the edge of the glass.
                let reach = max(0, wide - Metrics.playerMin)
                // How far the column has come out: all of itself while it is
                // open, and the hand's own worth while one is pulling it.
                let travel = menu ? column : min(max(pull, 0), column)
                ZStack(alignment: .topLeading) {
                    player(tight: wide - min(travel, reach) < Metrics.roomy)
                        .padding(.leading, min(travel, reach))

                    // The window's leading edge: a hand pulling the menu out.
                    puller

                    // The menu, over the player while it is on its way out and
                    // beside it once it is there. It is never in the way of
                    // anything while it is away: away means off the window's
                    // edge, where nothing can be clicked, and not merely
                    // invisible.
                    SideMenu(
                        engine: engine,
                        playlists: playlists,
                        span: $sideSpan,
                        refresh: fresh
                    )
                    .frame(width: column)
                    .offset(x: travel - column)
                }
                .frame(width: wide, height: room.size.height, alignment: .topLeading)
            }
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
        .toolbar {
            // The side menu's toggle, at the leading end and beside the traffic
            // lights, where a toggle for a column on the left belongs and where
            // macOS puts one: visible whether the column is out or away, which
            // is the whole of what a toggle has to be.
            ToolbarItem(placement: .navigation) {
                Button {
                    if menu { shut() } else { open() }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .buttonStyle(.borderless)
                .help(menu
                      ? "Hide the side menu   ⌥⌘S"
                      : "Show the side menu — playlists and their tracks   ⌥⌘S")
                .accessibilityLabel(menu ? "Hide the side menu" : "Show the side menu")
            }
            // The two things a player can be told about itself: a folder, and
            // which of the three looks it wears. Both were icons in a band of
            // the window's own before, and both are the platform's now.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Chooser.folder(into: playlists, for: engine)
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Add a folder of music — \(PlayerEngine.kinds)   ⌘O")
                .accessibilityLabel("Add Folder")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: walkLook) {
                    Image(systemName: look.icon)
                }
                .buttonStyle(.borderless)
                .help("Theme — \(look.title); click for \(look.next.title)")
                .accessibilityLabel("Theme")
            }
        }
        .onAppear {
            // Again, in case the app was not there yet when it was asked for
            // the first time (see DajetPlayerApp's init).
            Theme.remembered.apply()
            watchKeys()
            // The reading of the files the menu is about to show, if any, is
            // as old as the last time it was out.
            fresh += 1
            // The tray's last resort for bringing this window back, handed over
            // while there is one to hand it from.
            let reopen = openWindow
            Tray.reopen = { reopen(id: Self.windowID) }
        }
        .onDisappear {
            if let keys { NSEvent.removeMonitor(keys) }
            keys = nil
        }
    }

    // MARK: - the shape of the window

    /// The width the menu wants in the window, which is the width it was last
    /// pulled to, between the two it lives between.
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
    /// Only while the menu is away — an open menu has its own edge, and that
    /// one is for sizing it. The toolbar's own band is not part of it: that
    /// band belongs to the window's drag, and to the buttons in it.
    private var puller: some View {
        Color.clear
            .frame(width: Metrics.pull)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
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

    /// The player: the one track that matters, and the transport under it. No
    /// band of its own along the top — that is the window's toolbar now, and
    /// the first thing in the body of this window is the music.
    ///
    /// `tight` is the player's own verdict on the room it has been given, and
    /// everything below it that can be drawn two ways is: a window resized down
    /// is a window that keeps the whole player in it, in less room, rather than
    /// one that loses the end of a slider off its edge.
    private func player(tight: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: tight ? 4 : 12)
            middle(tight: tight)
            Spacer(minLength: tight ? 4 : 12)
            foot(tight: tight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The middle of the window: what is playing, or the invitation to drop
    /// something on it, or whatever the player has to say instead of a track.
    @ViewBuilder
    private func middle(tight: Bool) -> some View {
        if let track = engine.track {
            nowPlaying(track, tight: tight)
        } else if let note = engine.note {
            saying(note, tight: tight)
        } else {
            invitation(tight: tight)
        }
    }

    /// What is playing: the sleeve, and the names on it. Nothing else — the
    /// list of the folder is in the menu, where it is a list of somewhere,
    /// and the window in front of the listener is the one track that is
    /// actually being heard.
    ///
    /// The sleeve is whatever the file said — its own embedded cover, or the
    /// picture lying beside it in the folder, or nothing at all, which is the
    /// engine's business and not this one's (see Artwork.swift).
    private func nowPlaying(_ track: URL, tight: Bool) -> some View {
        VStack(spacing: tight ? 12 : 20) {
            Cover(cover: engine.cover)
            VStack(spacing: 5) {
                Text(engine.title ?? track.deletingPathExtension().lastPathComponent)
                    .font(.system(size: tight ? 16 : 19, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(track.lastPathComponent)
                if let artist = engine.artist {
                    Text(artist)
                        .font(.system(size: tight ? 12 : 13))
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
        .padding(.horizontal, tight ? 14 : 36)
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
    private func invitation(tight: Bool) -> some View {
        VStack(spacing: tight ? 10 : 16) {
            Wave(crests: 2, height: 0.34)
                .stroke(
                    Palette.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(width: tight ? 64 : 92, height: tight ? 28 : 40)
            VStack(spacing: 5) {
                Text("Drop a folder of music, or a few files.")
                    .font(.system(size: tight ? 13 : 14))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text("\(PlayerEngine.kinds)  ·  ⌘O adds a folder to the menu")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, tight ? 14 : 36)
    }

    /// The player has something to say that is not a track: nothing that was
    /// opened is music, or the queue has played itself out and the last of it
    /// is still there to be played again.
    private func saying(_ note: String, tight: Bool) -> some View {
        VStack(spacing: tight ? 10 : 16) {
            Wave(crests: 2, height: 0.3)
                .stroke(
                    Palette.faint,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: tight ? 56 : 76, height: tight ? 24 : 32)
            Text(note)
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, tight ? 14 : 36)
    }

    /// The foot of the window: how far into the track the player is and where
    /// a hand can take it to, then everything that can be pressed. All of it
    /// is the engine's — every button here is a hand on something the core
    /// already did in P-03 to P-05 — and only the drawing of it is this
    /// version's.
    private func foot(tight: Bool) -> some View {
        VStack(spacing: tight ? 10 : 16) {
            progress(tight: tight)
            transport(tight: tight)
        }
        .padding(.horizontal, tight ? 12 : 28)
        .padding(.bottom, tight ? 12 : 18)
    }

    /// The line the track is drawn along, the two times at its ends, and the
    /// hand that can take it elsewhere.
    ///
    /// While a hand is on it the line follows the hand and the music does not
    /// move one bit: a drag that dragged the sound along would stutter the
    /// track through every place the thumb passed. Let go, and the track is
    /// taken to that place, playing or paused as it was — which is exactly
    /// what the bar at the foot of the window has always done.
    private func progress(tight: Bool) -> some View {
        HStack(spacing: tight ? 8 : 12) {
            Text(clock(scrubbing ?? engine.position))
                .frame(width: tight ? 38 : 46, alignment: .trailing)
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
                .frame(width: tight ? 38 : 46, alignment: .leading)
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

    /// The transport: the three buttons that are always in the same place, with
    /// the two modes and the volume either side of them — and, in a window too
    /// narrow for one row of all seven, the same seven in two rows instead.
    ///
    /// Nothing is dropped when the window shrinks and nothing is hidden behind
    /// anything: a player whose shuffle button goes away at a narrow width is a
    /// player that has taken a setting away because of the size of a window.
    /// What changes is the air between them, and the row they are on.
    @ViewBuilder
    private func transport(tight: Bool) -> some View {
        if tight {
            VStack(spacing: 8) {
                hands(tight: tight)
                HStack(spacing: 10) {
                    shuffleButton(tight: tight)
                    repeatButton(tight: tight)
                    Spacer(minLength: 8)
                    muteButton(tight: tight)
                    loudness(tight: tight)
                }
            }
        } else {
            HStack(spacing: 16) {
                shuffleButton(tight: tight)
                repeatButton(tight: tight)

                Spacer(minLength: 18)

                hands(tight: tight)

                Spacer(minLength: 18)

                muteButton(tight: tight)
                loudness(tight: tight)
            }
        }
    }

    /// The three that matter most, and the three that are always together: back,
    /// play or pause, on.
    private func hands(tight: Bool) -> some View {
        HStack(spacing: tight ? 12 : 16) {
            Door(
                icon: "backward.fill",
                help: "Previous — the start of this track, once three seconds of it have gone by",
                size: tight ? 30 : 34,
                glyph: tight ? 14 : 15,
                enabled: engine.count > 0,
                act: { engine.previous() }
            )
            playButton(tight: tight)
            Door(
                icon: "forward.fill",
                help: "Next track",
                size: tight ? 30 : 34,
                glyph: tight ? 14 : 15,
                enabled: engine.count > 0,
                act: { engine.next() }
            )
        }
    }

    private func shuffleButton(tight: Bool) -> some View {
        Door(
            icon: "shuffle",
            help: engine.shuffle
                ? "Shuffled — click to walk the queue in the order it was opened"
                : "In order — click to shuffle the queue",
            on: engine.shuffle,
            size: tight ? 26 : 30,
            glyph: tight ? 12 : 13,
            act: { engine.toggleShuffle() }
        )
    }

    private func repeatButton(tight: Bool) -> some View {
        Door(
            icon: engine.repeatMode == .one ? "repeat.1" : "repeat",
            help: repeatHelp,
            on: engine.repeatMode != .off,
            size: tight ? 26 : 30,
            glyph: tight ? 12 : 13,
            act: { engine.cycleRepeat() }
        )
    }

    private func muteButton(tight: Bool) -> some View {
        Door(
            icon: engine.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            help: engine.muted ? "Muted — click to hear it again" : "Mute",
            on: engine.muted,
            size: tight ? 26 : 30,
            glyph: tight ? 11 : 12,
            act: { engine.toggleMute() }
        )
    }

    /// How loud, in a slider that is as wide as the window has room for and no
    /// wider: at a narrow width it is a short slider, and it is still the same
    /// slider, remembering the same number between runs.
    private func loudness(tight: Bool) -> some View {
        Slider(value: volume, in: 0...1)
            .frame(width: tight ? 44 : 66)
            .controlSize(.small)
            .tint(Palette.accent)
            .help("Volume — remembered between runs")
            .accessibilityLabel("Volume")
    }

    /// Play, or pause: the one button in the window that is a shape rather
    /// than a glyph, and the one thing in it that is the accent all the way
    /// through. Nothing is playing and it says so by going quiet rather than
    /// by going away.
    private func playButton(tight: Bool) -> some View {
        let side: CGFloat = tight ? 44 : 52
        return Button { engine.toggle() } label: {
            Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                .font(.system(size: tight ? 15 : 17, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                // A play triangle is wider on one side than the other; a
                // single point of nudge puts it in the middle of the circle.
                .offset(x: engine.state == .playing ? 0 : 1.5)
                .frame(width: side, height: side)
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
    private var volume: Binding<Float> {
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
    /// toolbar — and by the tray's own submenu, which writes the same key and
    /// is answered by the same `@AppStorage`. Three states on a button this
    /// small are only legible while it says which one it is in, so it wears the
    /// glyph of what is on and says the rest in its tooltip.
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
    /// menu — the browser's own shortcut for its column. It is in the key
    /// monitor rather than on the toolbar's toggle because a monitor hears it
    /// whether or not anything in the window has the keyboard, and because the
    /// toggle is the one button in the window that a hand may be looking for
    /// while the column is shut.
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
