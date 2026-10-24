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
// (P-10): the side menu's toggle at the leading end beside the traffic lights
// is the split view's own — the one NavigationSplitView puts there itself —
// and the two things a player can be told about itself — a folder, and which
// of the three looks it wears — are at the other. The window keeps no toggle
// of its own: two identical switches taught nobody anything (issue #16).
//
// The side menu is no longer a view the window pulls over itself: it is an
// element of a two-column `NavigationSplitView` — on macOS the wrapper around
// the platform's own `NSSplitViewController` — so the column has the system's
// divider, the system's collapse, and the system's animation, and it can
// never be *over* the player again, because a split element is beside its
// detail by construction (issue #15). The window's own minimum says the same
// thing out loud: while the column is out, the window is never narrower than
// the column plus the template's own width — `contentMinSize`, said
// from the view here and written on the window itself by Presentation, and
// before the column comes out in a window too narrow for both, the window
// grows to hold them. The hand-pulled edge, the spring of its own, and the
// drawer that went over the transport in a narrow window are all gone with
// the arithmetic that needed them. Inside the column are playlists — folders
// of music, added by ⌘O or by being dropped on the window, kept until they
// are removed, and there for the next run (Playlists.swift, Side.swift).
//
// The look covers the whole window — glass in the light theme, matte
// almost-black in the dark — and the window itself is dressed for it
// (Window.swift, Design.swift).
//
// None of this touches what the player does. Space plays and pauses from the
// moment the window opens, with nothing clicked and nothing focused, the two
// arrows walk the queue beside it — unless the progress line has the
// keyboard, in which case the arrows are its five seconds — the Mac's own
// media keys and its Now Playing card are the app's, volume and mute are
// remembered, and a folder dropped on the window plays at once — all of it
// the engine's, exactly as P-03 to P-05 left it. And the player is not the
// window's any more: the tray owns it, so closing the window leaves the
// music playing and the menu bar in charge of it (Tray.swift).

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
        AppearancePreferences.prepare()
        let remembered = Look.current
        DispatchQueue.main.async { remembered.apply() }
    }

    var body: some Scene {
        Window("Dajet Player", id: PlayerView.windowID) {
            PlayerView(engine: tray.engine, playlists: tray.playlists, presentation: tray.presentation)
        }
        // The system's own toolbar, with no title in it: the buttons are the
        // window's, the traffic lights are macOS's, and the band they share is
        // transparent, so the glass underneath is the glass of the whole window
        // rather than of everything below a bar (see Window.swift).
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: WindowTemplate.initialContentSize.width,
                     height: WindowTemplate.initialContentSize.height)
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
            // The View menu's word for the column — the one menu-bar item a
            // column toggle keeps — said through the window's single road:
            // `sideOpen`, the same word the toolbar's system toggle, the
            // tray's tick and the split's own binding say. The system's own
            // `SidebarCommands` went with the AppKit action it carries: that
            // action toggles the split behind the binding's back — it answers
            // success, and the column comes back to where the binding says it
            // lies (issue #16). The shortcut is the browser's own ⌥⌘S, which
            // the key monitor used to carry and the menu now does, in one
            // place.
            // In the View menu the system already owns, not in a second menu
            // of the same name: two "View"s in the menu bar read as breakage
            // (acceptance, P4).
            CommandGroup(after: .toolbar) {
                Button("Toggle Side Menu") {
                    withAnimation(.smooth) { tray.presentation.sideOpen.toggle() }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
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
    @ObservedObject var presentation: Presentation

    /// The look that is on, kept between runs under the one key.
    @AppStorage(Look.key) private var lookName = Look.system.rawValue
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
    /// Whether the bar has the keyboard, kept where the key monitor can read
    /// it: the monitor was installed before SwiftUI's focus system and cannot
    /// ask a focus state directly, so this box is told instead (see the
    /// `onChange` of `barFocused` below).
    @State private var barFocus = FocusBox()
    /// The keyboard, while the progress line is the one thing on the window
    /// that has it: the arrows are then the line's five seconds, and nobody
    /// else's.
    @FocusState private var barFocused: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
            WindowDress(glass: scheme == .light && !reduceTransparency, presentation: presentation)
                .frame(width: 0, height: 0)

            // The column and the player, held by the system's own split view:
            // the sidebar is its element and the player is its detail, so the
            // two are beside each other by construction, the line between them
            // is the platform's divider, and opening and closing the column is
            // the platform's motion. Nothing here is laid out by hand any
            // more, so nothing here can end up under anything else (issue #15).
            NavigationSplitView(columnVisibility: column) {
                SideMenu(engine: engine, playlists: playlists, refresh: fresh)
                    // The column's width, in the two numbers it always lived
                    // between and at the one it rests at: told here, where the
                    // split asks for it, and held there by the system's
                    // divider.
                    .navigationSplitViewColumnWidth(
                        min: columnRange.lowerBound,
                        ideal: restingWidth,
                        max: columnRange.upperBound
                    )
            } detail: {
                GeometryReader { room in
                    templatePlayer(horizontal: horizontal(in: room.size), size: room.size)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The window's minimum, in the one place that sees both states: the
        // formal square while the column is away, and — while it is out — the
        // column plus the width of the template's own player (the player is
        // never squeezed under its template; issue #16). Presentation says the
        // same number to the window itself; between the two of them, an
        // overlay has nothing left to be (issue #15).
        .frame(minWidth: presentation.contentMinWidth, minHeight: Metrics.side)
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
            // The side menu's toggle is not here: the split view brings its own
            // — at the leading end, beside the traffic lights, where a toggle
            // for a column on the left belongs — and its press lands in the
            // visibility binding below, the same single road every other
            // toggler takes. A second switch of our own above it was two
            // identical buttons for one job (issue #16).
            //
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
            Look.current.apply()
            watchKeys()
            // The reading of the files the menu is about to show, if any, is
            // as old as the last time it was out.
            fresh += 1
            // The tray's last resort for bringing this window back, handed over
            // while there is one to hand it from.
            let reopen = openWindow
            Tray.reopen = { reopen(id: Self.windowID) }
            // The tray's Side Menu item, given the same system motion the
            // toolbar's toggle gets: the column slides because the change
            // arrives inside a SwiftUI transaction, not because anything here
            // keeps a spring for it.
            let presentation = presentation
            Tray.toggleSideThroughWindow = {
                withAnimation(.smooth) { presentation.sideOpen.toggle() }
            }
        }
        .onChange(of: presentation.sideOpen) { _, isOpen in
            if isOpen { fresh += 1 }
        }
        .onChange(of: lookName) { _, _ in
            look.apply()
        }
        .onChange(of: barFocused) { _, focused in
            // The line has the keyboard, said where the key monitor can read
            // it (see the box it is kept in, above).
            barFocus.focused = focused
        }
        .onDisappear {
            if let keys { NSEvent.removeMonitor(keys) }
            keys = nil
        }
    }

    // MARK: - the shape of the window

    /// Whether the player is drawn as the wide card or the tall one: the
    /// template's own word and, for Custom — which has no template — the
    /// window's own shape, said the way it always was: wide enough to be a
    /// card, and wider than it is tall.
    private func horizontal(in size: CGSize) -> Bool {
        presentation.template == .horizontal
            || (presentation.template == .custom && size.width >= 480 && size.width > size.height)
    }

    /// The two numbers the column's width lives between: the templates' own
    /// range, and Custom's wider one. The split owns the width now; this is
    /// where it is told the range (App.swift's column modifier).
    private var columnRange: ClosedRange<Double> {
        presentation.template == .custom
            ? Double(Metrics.sideMin)...Double(Metrics.sideMax)
            : WindowTemplate.sideRange
    }

    /// The width the column comes out at, in a template or in Custom.
    private var restingWidth: Double {
        presentation.template == .custom ? Double(Metrics.side) : WindowTemplate.sideRest
    }

    /// The split's column visibility, seen from the window's own word for it:
    /// the system's toolbar toggle, the tray's tick, the View menu and ⌥⌘S
    /// all say `sideOpen`, and the split says it back through this same
    /// binding when the system's own toggle or divider moves it. The set
    /// keeps to the two answers the macOS split writes into the binding —
    /// the column out is `.all`, the column away is `.detailOnly` — and
    /// anything else means nothing this window listens to.
    private var column: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { presentation.sideOpen ? .all : .detailOnly },
            set: { shown in
                switch shown {
                    // What the system itself writes into the binding on macOS:
                    // the column out is `.all`, the column away is `.detailOnly`.
                    // (`NavigationSplitViewVisibility` has no `.sidebar` — that
                    // one belongs to `NavigationSplitViewColumn`; `.automatic`
                    // and `.doubleColumn` say nothing this window listens to.)
                case .all: presentation.sideOpen = true
                case .detailOnly: presentation.sideOpen = false
                default: break
                }
            }
        )
    }

    private var look: Look { Look(rawValue: lookName) ?? .system }

    // MARK: - the player

    /// P-10R measured content, re-centred (issue #15): the cover beside one
    /// vertically centred block — the names, the line, and everything that
    /// can be pressed under them — so nothing is pressed down into the bottom
    /// of the column and nothing spreads into loose lines of its own.
    /// H-A: 200 + 16 + 300 inside 516 × 212.
    /// H-B: 160 + 12 + 152 inside 324 × 212.
    /// V-A: 352 pt stack inside 200 × 365, centred (13 pt spare).
    private func templatePlayer(horizontal: Bool, size: CGSize) -> some View {
        Group {
            if engine.track != nil {
                if horizontal {
                    // Room for everything on one row is the same 500 it always
                    // was; below it the same controls are two rows, and nothing
                    // is dropped, hidden or squeezed off the end.
                    let roomy = size.width >= Metrics.roomy
                    let art = min(roomy ? 200.0 : 160.0,
                                  max(0, size.height - 20),
                                  max(0, size.width - (roomy ? 200 : 188)))
                    HStack(spacing: roomy ? 16 : 12) {
                        Cover(cover: engine.cover).frame(width: art, height: art)
                        VStack(spacing: 0) {
                            templateNames(titleHeight: 40, subtitleHeight: roomy ? 18 : 16)
                            Color.clear.frame(height: roomy ? 14 : 8)
                            progress(tight: true).frame(height: Metrics.scrubStrip)
                            Color.clear.frame(height: roomy ? 12 : 8)
                            if roomy {
                                // One row: the modes with the volume beside
                                // them, and the transport centred between.
                                HStack(spacing: 12) {
                                    modesAndVolume
                                    Spacer(minLength: 12)
                                    templateHands
                                    Spacer(minLength: 12)
                                }
                            } else {
                                VStack(spacing: 10) {
                                    templateHands
                                    modesAndVolume
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, roomy ? 16 : 12)
                    .padding(.vertical, 10)
                } else {
                    VStack(spacing: 0) {
                        // Custom may be as short as 232 pt of content. Only the
                        // cover shrinks; seek and transport keep their hit areas.
                        let art = min(200.0, max(0, size.width - 32), max(0, size.height - 176))
                        Cover(cover: engine.cover).frame(width: art, height: art)
                        Color.clear.frame(height: 10)
                        templateNames(titleHeight: 36, subtitleHeight: 16)
                        Color.clear.frame(height: 8)
                        progress(tight: true).frame(height: Metrics.scrubStrip)
                        Color.clear.frame(height: 10)
                        templateHands
                        Color.clear.frame(height: 10)
                        modesAndVolume
                    }
                    .frame(maxWidth: 240)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else {
                // No phantom cover or duplicate Open Folder action when idle.
                VStack(spacing: 12) {
                    if let note = engine.note { saying(note, tight: true) }
                    else { invitation(tight: true) }
                    templateHands
                    modesAndVolume
                }
                .padding(16)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func templateNames(titleHeight: CGFloat, subtitleHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(engine.title ?? engine.track?.deletingPathExtension().lastPathComponent ?? "")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: titleHeight)
                .help(engine.track?.lastPathComponent ?? "")
            Text([engine.artist, engine.album].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .frame(height: subtitleHeight)
        }
    }

    /// Three glyphs, 26 pt each with 12 pt gaps. Modes remain in the volume row
    /// where there is room, and are always accessible from the tray.
    ///
    /// The door is the package's own now, and it has no state for a door that
    /// cannot be opened — so the window says that state around it: held, and
    /// pale. A row that loses its buttons when there is nothing to press is a
    /// row that moves about while it is being read.
    private var templateHands: some View {
        HStack(spacing: 12) {
            Door("backward.fill",
                 help: "Previous — restart after three seconds",
                 act: { engine.previous() })
                .doorHeld(engine.count == 0)
            Door(engine.state == .playing ? "pause.fill" : "play.fill",
                 on: true,
                 help: engine.state == .playing ? "Pause (Space)" : "Play (Space)",
                 act: { engine.toggle() })
                .doorHeld(engine.count == 0)
            Door("forward.fill",
                 help: "Next track",
                 act: { engine.next() })
                .doorHeld(engine.count == 0)
        }
        .frame(height: 26)
    }

    /// The two modes and the volume beside them, said compactly: three doors
    /// and a short slider. The slider is short because a volume that is half
    /// the column wide is a slider with opinions about the column's width
    /// (issue #15); the same compact row is what every layout holds — the wide
    /// card beside its transport, the tall card under its own.
    private var modesAndVolume: some View {
        HStack(spacing: 8) {
            Door("shuffle", on: engine.shuffle, help: "Shuffle",
                 act: { engine.toggleShuffle() })
            Door(engine.repeatMode == .one ? "repeat.1" : "repeat",
                 on: engine.repeatMode != .off, help: repeatHelp,
                 act: { engine.cycleRepeat() })
            Door(engine.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                 on: engine.muted,
                 help: engine.muted ? "Unmute" : "Mute",
                 act: { engine.toggleMute() })
            Slider(value: volume, in: 0...1)
                .frame(width: 44)
                .controlSize(.mini)
                .tint(Palette.accent)
                .help("Volume — remembered between runs")
                .accessibilityLabel("Volume")
        }
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

    /// The line the track is drawn along, the two times at its ends, and the
    /// hand that can take it elsewhere.
    ///
    /// It is still this window's own drawing — dragging along the track of a
    /// system control is not something the platform offers — but the strip it
    /// lives on is sixteen points, the least the platform's own controls
    /// would carry, and it takes the keyboard while it has it: the arrows
    /// step five seconds (issue #15).
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
            // Sixteen points of strip around a four-point line: the line is
            // the drawing, the strip is where a hand and the keyboard land.
            .frame(height: Metrics.scrubStrip)
            .focusable(true)
            .focused($barFocused)
            // The ring is the one system ornament this window does not draw:
            // the strip answers the keyboard and says so with the knob it
            // already has rather than with a ring it never had.
            .focusEffectDisabled()
            .onKeyPress(.leftArrow) { step(-5) }
            .onKeyPress(.rightArrow) { step(5) }
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
        .help(scrubbable
              ? "Playback position — drag, or step five seconds with the arrow keys"
              : "Playback position")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((filled * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: engine.seek(to: engine.position + 5)
            case .decrement: engine.seek(to: engine.position - 5)
            @unknown default: break
            }
        }
    }

    /// Five seconds at a time, from the keyboard, while the line has it: the
    /// engine clamps the step to the track's own ends. Handled, so a held key
    /// walks the line and nothing else's handler hears it.
    private func step(_ seconds: TimeInterval) -> KeyPress.Result {
        guard scrubbable else { return .ignored }
        engine.seek(to: (scrubbing ?? engine.position) + seconds)
        return .handled
    }

    /// Something is being carried over the window: the whole of it says so,
    /// and says what will happen when it is let go.
    private var dropHint: some View {
        ZStack {
            Palette.accent.opacity(0.06)
            RoundedRectangle(cornerRadius: Radius.item + 3, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.55), lineWidth: 2)
                .padding(7)
            Text("Let go to play.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Radius.item, style: .continuous)
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
    /// The two arrows are not keys of the player's own: they belong to the
    /// progress line while it has the keyboard (its five seconds at a time,
    /// issue #15), and the monitor reads the line's own little box and lets
    /// them through to it. ⌥⌘S, the side menu's own shortcut, is not here —
    /// the View menu carries it now, the one place a menu shortcut is said
    /// in, and the monitor leaves modified keys alone for the menu to answer
    /// (issue #16).
    private func watchKeys() {
        guard keys == nil else { return }
        let engine = engine
        let barFocus = barFocus
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Nothing here is a key in the folder panel: that panel is this
            // app's too, and its keys are its own.
            guard !(event.window is NSPanel) else { return event }
            // Bare keys, and one press at a time: a modifier makes a key into
            // another key entirely, and a held key repeats — a player walked
            // by a held arrow would fly through the queue as fast as the
            // keyboard could say so, and a held space would start and stop the
            // music just as fast. (A held arrow while the progress line has
            // the keyboard is the line's own walk, and the line steps on it.)
            let borrowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.modifierFlags.isDisjoint(with: borrowed), !event.isARepeat else {
                return event
            }
            switch event.keyCode {
            case 49:    // space, the one key a player cannot do without
                MainActor.assumeIsolated { engine.toggle() }
                return nil
            case 123:   // left: the line's five seconds while it has the keyboard,
                        // and this track again — or the one before it — otherwise
                if barFocus.focused { return event }
                MainActor.assumeIsolated { engine.previous() }
                return nil
            case 124:   // right: the line's step, or the next track
                if barFocus.focused { return event }
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
            .clipShape(RoundedRectangle(cornerRadius: Radius.item + 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.item + 2, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 22, y: 12)
            .frame(width: room.size.width, height: room.size.height, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Whether the progress line has the keyboard, kept where the key monitor can
/// read it: the monitor was installed before SwiftUI's focus system and
/// cannot ask a focus state directly, so the view keeps this little box told
/// (the `onChange` of `barFocused`) and the monitor reads it instead.
final class FocusBox: @unchecked Sendable {
    var focused = false
}

/// The state the package's door does not carry itself: a door that cannot be
/// opened still stands where it is, greyed — held, and pale, and taking no
/// clicks — so that a row with nothing to press keeps its shape.
private extension View {
    func doorHeld(_ held: Bool) -> some View {
        disabled(held)
            .opacity(held ? 0.35 : 1)
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
