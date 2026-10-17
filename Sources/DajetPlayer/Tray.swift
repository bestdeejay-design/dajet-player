import AppKit
import Combine

// The tray: the player's own place in the menu bar, and the one part of it
// that is there whether a window is or not.
//
// What it is follows what the players that live in a menu bar have settled on
// — Sonora's, Swinsian's, IINA's, and Apple's own Music in Control Center —
// and what the platform's own guidance says of an `NSStatusItem`:
//
//   · a template image, drawn here rather than loaded, so that the mark is the
//     app's own wave and the menu bar decides what colour it wears in the
//     light and in the dark;
//   · an `NSMenu`, and not a popover: a player is a list of things to do and
//     not a second window, and a menu is what a hand expects of an icon up
//     there;
//   · a menu built as it opens (`menuNeedsUpdate`) rather than kept in step
//     while it is shut — a status item whose menu is rebuilt on every tick of
//     a track costs something for nothing, and one built as it opens is always
//     right and never early;
//   · submenus that fill themselves when *they* are opened, so that a library
//     of twelve folders is not twelve directory listings for a menu nobody has
//     looked into;
//   · and an icon that moves only while the music does: the animation is a
//     timer that exists for as long as a track plays and for not one moment
//     longer, which is what keeps an idle player at nought.
//
// The tray owns the player and the playlists, and the window reads them from
// it — rather than the other way round, which would leave the tray without a
// player every time the window was closed, and a closed window is exactly when
// a tray is for.

/// The menu bar's own copy of the player: the icon, its menu, and the two
/// things it owns for the life of the app.
@MainActor
final class Tray: NSObject, NSApplicationDelegate, NSMenuDelegate {

    /// The player, made here at launch rather than by a window that may never
    /// open, and held for as long as the app runs.
    let presentation = Presentation()
    let engine = PlayerEngine()
    /// The playlists, and the file they live in — read here for the same
    /// reason, so that the menu has them whether a window has been there or
    /// not.
    let playlists = Playlists()

    /// SwiftUI's own way of asking for the window back, handed over by the
    /// window while it is there. The tray looks for a window first and asks
    /// this only when there is none to find, which is what a closed `Window`
    /// scene leaves behind: nothing among the app's windows, and a scene that
    /// will make one again when it is asked.
    /// The window's own way back, installed by the window while there is one:
    /// the last resort for bringing the player forward from here.
    static var reopen: (@MainActor () -> Void)?

    /// The Side Menu item's way through the window, installed the same way:
    /// the toggle arrives inside a SwiftUI transaction, so the split answers
    /// it with the system's own animation instead of the column jumping
    /// (issue #15). Nothing installed — no window has been up yet — and the
    /// model's own flag is the answer, which the split reads through its
    /// binding.
    static var toggleSideThroughWindow: (@MainActor () -> Void)?

    /// The item in the menu bar. Held, because an `NSStatusItem` nobody holds
    /// is an item that is gone: the status bar keeps no reference of its own.
    private var item: NSStatusItem?
    /// The menu, and the delegate that fills it as it opens.
    private var root = NSMenu()
    /// The clock that moves the icon, and only while there is music to move it
    /// for. No timer at all when nothing plays.
    private var pulse: Timer?
    /// Which frame of the dance the icon is on.
    private var step = 0
    /// The ear on the player's state: what starts and stops the dance.
    private var watching: AnyCancellable?
    private var accessibilityObserver: NSObjectProtocol?

    /// What this player keeps of its tray, in the plainest drawer macOS has —
    /// the same corner of the standard defaults the volume and the look live
    /// in. Nothing is sent anywhere.
    enum Prefs {
        /// Whether the Dock's icon is hidden and the tray is the only way in.
        static let dock = "hideDockIcon"
        /// Whether the icon dances while a track plays.
        static let motion = "animateTray"

        /// Read as they are asked for rather than kept: a setting changed in
        /// one menu is a setting the next menu shows, and a flag held in two
        /// places is two chances to disagree with itself.
        static var hidesDock: Bool {
            get { UserDefaults.standard.bool(forKey: dock) }
            set { UserDefaults.standard.set(newValue, forKey: dock) }
        }

        /// On until it is turned off, which is the way round a thing that is
        /// only ever switched off on purpose wants to be.
        static var dances: Bool {
            get {
                UserDefaults.standard.object(forKey: motion) == nil
                    || UserDefaults.standard.bool(forKey: motion)
            }
            set { UserDefaults.standard.set(newValue, forKey: motion) }
        }
    }

    // MARK: - launching

    /// As early as the app is able to speak. A listener who asked to live in
    /// the menu bar only should not have to watch a Dock icon appear and then
    /// go away again on every launch — and with `LSUIElement` written by a
    /// build script that has no opinion about settings, this is the one place
    /// the icon can be kept from appearing at all. Only when the setting is
    /// on: an app that wants a Dock icon is an app that already has one, and
    /// taking it away and giving it back is a flicker for nothing.
    func applicationWillFinishLaunching(_ notification: Notification) {
        if Prefs.hidesDock { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Icon.still
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "Dajet Player"
        root.delegate = self
        root.autoenablesItems = false
        item.menu = root
        self.item = item
        // A player told to live in the tray only is one the next run starts the
        // same way, and starts that way before a window is drawn: an icon
        // appearing in the Dock and going away again is an icon that looked
        // like a mistake.
        dress()
        // The icon follows the player, and the player is followed rather than
        // asked: one subscription for the life of the app, landing on the main
        // queue, which is where the icon is drawn and where the player lives.
        watching = engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                // A closure handed to a publisher is not a place the compiler
                // believes is the main actor, whatever queue it lands on.
                MainActor.assumeIsolated { self?.beat(state) }
            }
        beat(engine.state)
        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.beat(self.engine.state)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pulse?.invalidate()
        if let accessibilityObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityObserver)
        }
    }

    /// Closing the window is not closing the player, and it is not closing the
    /// app either: the music goes on, the icon stays in the menu bar, and the
    /// window comes back when it is asked for. Said here rather than left to
    /// whatever the platform's default turns out to be, because it is the whole
    /// of what a tray is for.
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        false
    }

    // MARK: - the icon

    /// What the player has become, said in the icon: dancing while the music
    /// plays, still while it does not, and the tooltip carrying the name of the
    /// track rather than of the app, because a menu bar is a place where one
    /// glance is all anybody gives it.
    private func beat(_ state: PlayerEngine.State) {
        guard let item else { return }
        if state == .playing, Prefs.dances, !Motion.reduced {
            dance()
        } else {
            rest(state)
        }
        item.button?.toolTip = tooltip
    }

    /// The tooltip: what is playing, or the app's own name when nothing is.
    private var tooltip: String {
        guard let url = engine.track else { return "Dajet Player" }
        let title = engine.title ?? url.deletingPathExtension().lastPathComponent
        guard let artist = engine.artist else { return "Dajet Player — \(title)" }
        return "Dajet Player — \(title), \(artist)"
    }

    /// Start the dance, if it is not already going. One timer, four frames a
    /// second, eight small steps round and round: enough to read as movement at the
    /// size a menu bar icon is, and a fraction of a percent of a core.
    private func dance() {
        guard pulse == nil else { return }
        pulse = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            // A timer's tick is on the main run loop, and the icon is drawn
            // there; said so, because a closure handed to a timer is not a
            // place the compiler believes is the main actor either.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.step = (self.step + 1) % 8
                self.item?.button?.image = Icon.playing(self.step)
            }
        }
        item?.button?.image = Icon.playing(step)
    }

    /// Stop it, and put the still mark back: a paused player is a player that
    /// has something to say and is not saying it with movement. With the Mac
    /// asked to reduce motion, or the dance turned off in the tray's own
    /// settings, this is where a *playing* player is drawn too — the bars, but
    /// standing still, which says the same thing without moving.
    private func rest(_ state: PlayerEngine.State) {
        pulse?.invalidate()
        pulse = nil
        step = 0
        item?.button?.image = state == .playing ? Icon.playing(0) : Icon.still
    }

    // MARK: - the menu

    /// The menu as it opens: everything in it is asked for now, so that a track
    /// that changed while the menu was shut, a folder added since and a theme
    /// switched from the window are all of them what the menu says.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if menu === root {
            whole(menu)
        } else if let folder = menu as? FolderMenu, let playlist = folder.playlist {
            tracks(of: playlist, in: menu)
        }
    }

    /// The whole of it, in the order a hand learns once: what is playing, the
    /// three buttons that are the player, the folders, the ways to change
    /// things, and the two ways out of it.
    private func whole(_ menu: NSMenu) {
        nowPlaying(in: menu)
        menu.addItem(.separator())
        transport(in: menu)
        quickControls(in: menu)
        menu.addItem(.separator())
        folders(in: menu)
        menu.addItem(.separator())
        let folder = act(#selector(choose), "Open Folder…", "folder.badge.plus", "o", .command)
        folder.toolTip = "A folder of music — \(PlayerEngine.kinds). It joins the menu, and it plays."
        menu.addItem(folder)
        menu.addItem(submenu("Window", icon: "macwindow") { sizes in
            for template in WindowTemplate.allCases where template != .custom {
                let one = self.act(#selector(self.windowSize(_:)), template.title)
                one.representedObject = template.rawValue
                one.state = template == self.presentation.template ? .on : .off
                sizes.addItem(one)
            }
            if self.presentation.template == .custom { sizes.addItem(self.plain("Custom")) }
        })
        menu.addItem(self.tick(
            "Side Menu", on: presentation.sideOpen,
            help: "Show or hide the column — ⌥⌘S", act: #selector(toggleSide)
        ))
        menu.addItem(submenu("Settings", icon: "slider.horizontal.3") { settings in
            settings.addItem(self.submenu("Appearance", icon: Theme.remembered.icon) { appearance in
                for preset in AppearancePreset.allCases {
                    let one = self.act(#selector(self.appearance(_:)), preset.title)
                    one.representedObject = preset.rawValue
                    one.state = preset == self.presentation.preset ? .on : .off
                    appearance.addItem(one)
                }
            })
            settings.addItem(self.tick(
                "Hide Dock Icon",
                on: Prefs.hidesDock,
                help: "Live in the menu bar only — the window is opened from here, "
                    + "and the app is out of ⌘Tab while it is",
                act: #selector(self.dock)
            ))
            settings.addItem(self.tick(
                "Animate the Icon While Playing",
                on: Prefs.dances,
                help: "The bars dance while a track plays",
                act: #selector(self.motion)
            ))
        })
        menu.addItem(.separator())
        menu.addItem(act(#selector(summon), Self.found()?.isVisible == true
                         ? "Hide Dajet Player" : "Show Dajet Player", "macwindow"))
        // Quit with no target of its own: the action walks up the responder
        // chain to the application, which is the thing that terminates, and a
        // menu that answered its own Quit would be a second way of ending the
        // app that knows nothing about the first.
        menu.addItem(NSMenuItem(
            title: "Quit Dajet Player",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    /// What is playing: the track's own name, and under it everything else the
    /// file said, in one line. The name is a way in rather than a label — a
    /// click on what is playing opens the window that is playing it, which is
    /// the one thing anybody clicking a track's title in a menu bar wants.
    private func nowPlaying(in menu: NSMenu) {
        guard let url = engine.track else {
            menu.addItem(plain("Nothing playing"))
            menu.addItem(plain(engine.note ?? "Drop a folder of music on the window"))
            return
        }
        let said = engine.title ?? url.deletingPathExtension().lastPathComponent
        let head = NSMenuItem(title: said, action: #selector(showPlayer), keyEquivalent: "")
        head.target = self
        head.attributedTitle = NSAttributedString(
            string: said,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        head.toolTip = url.lastPathComponent
        menu.addItem(head)
        menu.addItem(plain(under))
    }

    /// The line under the title: whoever played it, whatever it came off, and
    /// where in the pass the player has got to. Each of the three is optional
    /// and none of them is a hole in the line when it is missing.
    private var under: String {
        var said: [String] = []
        if let artist = engine.artist { said.append(artist) }
        if let album = engine.album { said.append(album) }
        if engine.count > 0 { said.append("Track \(engine.number) of \(engine.count)") }
        let line = said.joined(separator: "  ·  ")
        return line.isEmpty ? "A file on this Mac" : line
    }

    /// The three buttons, in the order they are in the window and in the same
    /// three glyphs: a hand that knows one knows the other.
    private func transport(in menu: NSMenu) {
        let playing = engine.state == .playing
        let play = act(
            playing ? #selector(pause) : #selector(play),
            playing ? "Pause" : "Play",
            playing ? "pause.fill" : "play.fill"
        )
        play.isEnabled = engine.count > 0
        menu.addItem(play)
        let back = act(#selector(back), "Previous", "backward.fill")
        back.isEnabled = engine.count > 0
        menu.addItem(back)
        let on = act(#selector(forward), "Next", "forward.fill")
        on.isEnabled = engine.count > 0
        menu.addItem(on)
    }

    /// The playlists, as the side menu holds them: one submenu apiece, with the
    /// folder's tracks under its name, the folder being played and the track
    /// being heard both marked. Each folder's submenu fills itself as it is
    /// opened, so that a library is not a library's worth of directory listings
    /// to draw a menu nobody has looked into yet.
    private func folders(in menu: NSMenu) {
        menu.addItem(submenu("Playlists", icon: "music.note.list") { inside in
            guard !self.playlists.isEmpty else {
                inside.addItem(self.plain("No playlists yet"))
                inside.addItem(self.plain("Open Folder… adds one"))
                return
            }
            for playlist in self.playlists.list {
                let list = FolderMenu(title: playlist.name)
                list.playlist = playlist
                list.delegate = self
                list.autoenablesItems = false
                let one = NSMenuItem(title: playlist.name, action: nil, keyEquivalent: "")
                one.submenu = list
                one.image = Icon.glyph(playlist.there ? "folder" : "exclamationmark.triangle")
                one.isEnabled = playlist.there
                // The folder the player is walking, marked the way the side
                // menu marks it — and compared by path, because the same
                // folder arrives with a slash on the end of it from one place
                // and without one from another.
                if let source = self.engine.source, playlist.isFolder(source) {
                    one.state = .on
                }
                inside.addItem(one)
            }
        })
    }

    /// One folder's tracks, read as the submenu opens and by the same rules the
    /// player and the side menu read a folder with, so that all three are the
    /// same list in the same order and cannot come to disagree about what is in
    /// a folder.
    private func tracks(of playlist: Playlist, in menu: NSMenu) {
        guard playlist.there else {
            menu.addItem(plain("This folder is not there any more"))
            return
        }
        let found = PlayerEngine.tracks(in: playlist.url)
        guard !found.isEmpty else {
            menu.addItem(plain("Nothing to play in here — \(PlayerEngine.kinds)"))
            return
        }
        let whole = NSMenuItem(
            title: "Play “\(playlist.name)”", action: #selector(open(_:)), keyEquivalent: ""
        )
        whole.target = self
        whole.representedObject = playlist.path
        menu.addItem(whole)
        menu.addItem(.separator())
        for url in found {
            let one = NSMenuItem(
                title: url.deletingPathExtension().lastPathComponent,
                action: #selector(track(_:)), keyEquivalent: ""
            )
            one.target = self
            one.representedObject = [playlist.path, url.path]
            one.toolTip = url.lastPathComponent
            if heard(url) { one.state = .on }
            menu.addItem(one)
        }
    }

    /// Whether that track is the one being heard, by path — the same question
    /// the side menu asks, answered the same way.
    private func heard(_ url: URL) -> Bool {
        guard let track = engine.track else { return false }
        return Playlist.plain(track) == Playlist.plain(url)
    }

    // MARK: - what the menu does

    @objc private func play() { if engine.state != .playing { engine.toggle() } }
    @objc private func pause() { if engine.state == .playing { engine.toggle() } }
    @objc private func back() { engine.previous() }
    @objc private func forward() { engine.next() }

    /// A whole folder, from its first track: what a click on a playlist in the
    /// side menu does, and what the top of that folder's own submenu does here.
    @objc private func open(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        engine.open([URL(fileURLWithPath: path)])
        summon()
    }

    /// One track of one folder, on that folder's queue: the engine's own
    /// `play(_:in:)`, which is what a click on a track in the side menu is
    /// handed to as well.
    @objc private func track(_ sender: NSMenuItem) {
        guard let paths = sender.representedObject as? [String], paths.count == 2 else { return }
        engine.play(URL(fileURLWithPath: paths[1]), in: URL(fileURLWithPath: paths[0]))
        summon()
    }

    /// A folder chosen the Mac's way, which is the same two lines the menu
    /// bar's ⌘O and the toolbar's button are: it joins the menu and it plays.
    @objc private func choose() {
        // A panel wants an app in front of it to belong to, and an app that
        // lives in the menu bar may not be in front of anything: brought
        // forward first, so that a panel never opens behind whatever else is
        // on the screen.
        summon()
        Chooser.folder(into: playlists, for: engine)
    }

    /// One of the three looks, chosen from the tray and remembered under the
    /// one key the window reads — the same choice, from either side of it.
    @objc private func appearance(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let wanted = AppearancePreset(rawValue: name) else { return }
        presentation.select(wanted)
    }

    @objc private func windowSize(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let wanted = WindowTemplate(rawValue: name) else { return }
        presentation.select(wanted)
        showPlayer()
    }

    @objc private func toggleSide() {
        if let through = Self.toggleSideThroughWindow {
            MainActor.assumeIsolated { through() }
        } else {
            presentation.sideOpen.toggle()
        }
    }
    @objc private func shuffle() { engine.toggleShuffle() }
    @objc private func repeatMode() { engine.cycleRepeat() }
    @objc private func mute() { engine.toggleMute() }
    @objc private func setVolume(_ sender: NSMenuItem) {
        engine.setVolume(Float(sender.tag) / 100)
    }

    private func quickControls(in menu: NSMenu) {
        menu.addItem(tick("Shuffle", on: engine.shuffle,
                          help: "Shuffle the queue", act: #selector(shuffle)))
        let repeatTitle: String
        switch engine.repeatMode {
        case .off: repeatTitle = "Repeat: Off"
        case .all: repeatTitle = "Repeat: All"
        case .one: repeatTitle = "Repeat: One"
        }
        menu.addItem(tick(repeatTitle, on: engine.repeatMode != .off,
                          help: "Off → All → One", act: #selector(repeatMode)))
        menu.addItem(submenu("Volume", icon: "speaker.wave.2") { volume in
            volume.addItem(self.tick("Mute", on: self.engine.muted,
                                    help: "Mute without losing the volume", act: #selector(self.mute)))
            volume.addItem(.separator())
            for level in [0, 25, 50, 75, 100] {
                let one = self.act(#selector(self.setVolume(_:)), "\(level) %")
                one.tag = level
                one.state = abs(self.engine.volume - Float(level) / 100) < 0.001 ? .on : .off
                volume.addItem(one)
            }
        })
        // Snapshot on open, no second progress timer while the menu is shut.
        let duration = engine.duration.isFinite ? max(0, engine.duration) : 0
        let position = engine.position.isFinite ? max(0, engine.position) : 0
        let percent = duration > 0 ? Int((min(position / duration, 1) * 100).rounded()) : 0
        menu.addItem(plain("\(Self.clock(position)) / \(Self.clock(duration)) · \(percent) %"))
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(min(max(0, seconds), Double(Int.max / 2)))
        return whole >= 3600
            ? String(format: "%d:%02d:%02d", whole / 3600, whole / 60 % 60, whole % 60)
            : String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// The Dock's icon, away or back. Away means the tray is the only way in,
    /// which is what a player that lives in the menu bar wants; it also means
    /// the app is out of ⌘Tab and out of the Dock's own menu, because that is
    /// what an accessory app is on this platform. So the choice is the
    /// listener's, it is remembered, and it is off until it is asked for.
    @objc private func dock() {
        Prefs.hidesDock.toggle()
        dress()
    }

    /// The dance, on or off. With it off, a playing player wears the bars
    /// standing still, which says the same thing and costs nothing at all.
    @objc private func motion() {
        Prefs.dances.toggle()
        beat(engine.state)
    }

    /// The window, back: found among the app's own if it is there, asked of
    /// SwiftUI if it is not, and the app brought forward either way — an
    /// accessory app is not in front of anything until it says so.
    @objc private func summon() {
        if let window = Self.found(), window.isVisible {
            // Visibility, not focus: clicking the status item can take key status.
            window.orderOut(nil)
        } else {
            showPlayer()
        }
    }

    @objc private func showPlayer() {
        NSApp.activate()
        if let window = Self.found() {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            return
        }
        Self.reopen?()
        // SwiftUI makes the window on a turn of its own; bringing it forward
        // once it is there is what puts it in front rather than somewhere
        // behind everything else.
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                Self.found()?.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// The player's window, whichever way it can be found: by the id its scene
    /// keeps it under, then by the name it wears, then as the first window that
    /// is a window and not one of the app's panels.
    private static func found() -> NSWindow? {
        let windows = NSApp.windows
        if let byID = windows.first(where: { $0.identifier?.rawValue == PlayerView.windowID }) {
            return byID
        }
        if let byName = windows.first(where: { $0.title == "Dajet Player" }) { return byName }
        return windows.first { !($0 is NSPanel) && $0.canBecomeMain }
    }

    /// What the app is: an ordinary app with a place in the Dock, or an
    /// accessory that lives in the menu bar. Set at launch and whenever the
    /// setting changes, which is the runtime's own version of the plist's
    /// `LSUIElement` — and the version this app can have, because its plist is
    /// written by a build script that has no opinion about settings.
    private func dress() {
        let open = NSApp.windows.contains { $0.isVisible }
        NSApp.setActivationPolicy(Prefs.hidesDock ? .accessory : .regular)
        // A change of policy can take the windows with it: to AppKit the
        // Dock's icon and a window's place in front of everything else are
        // close enough to the same thing that hiding one has been known to
        // hide the other. So a window that was open before the switch is put
        // back after it, and hiding the Dock's icon hides the Dock's icon and
        // nothing else. At launch there is no window yet and nothing to put
        // back, which is why this is asked and not assumed.
        guard open else { return }
        NSApp.activate()
        Self.found()?.makeKeyAndOrderFront(nil)
    }

    // MARK: - the items themselves

    /// An item that does something, with this tray as its target and one of the
    /// system's shapes beside the words.
    private func act(
        _ selector: Selector,
        _ title: String,
        _ icon: String? = nil,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        if let icon { item.image = Icon.glyph(icon) }
        return item
    }

    /// An item that says something and does nothing: a line of the menu that is
    /// read rather than pressed.
    private func plain(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// A setting that is on or off, and says which.
    private func tick(
        _ title: String, on: Bool, help: String, act selector: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        item.toolTip = help
        return item
    }

    /// A submenu, made and filled in one place, with `autoenablesItems` off so
    /// that what is greyed in here is greyed on purpose.
    private func submenu(
        _ title: String,
        icon: String?,
        build: (NSMenu) -> Void
    ) -> NSMenuItem {
        let inside = NSMenu(title: title)
        inside.autoenablesItems = false
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = inside
        if let icon { item.image = Icon.glyph(icon) }
        build(inside)
        return item
    }
}

/// The submenu of one folder.
///
/// An `NSMenu` has no pocket of its own: no `representedObject`, and no way of
/// being asked whose tracks it is about to show. It could be reached through
/// the item it hangs from, but that is a walk through the menu above it at the
/// one moment the menu above it is being rebuilt, so the answer is kept where
/// the question is asked: on the submenu itself.
final class FolderMenu: NSMenu {
    /// The folder whose tracks this menu is asked for.
    var playlist: Playlist?
}

/// The pictures the tray wears, drawn rather than loaded: the app's own wave
/// for a player that is not playing, and the four bars that dance while one is.
///
/// Drawn because there is nowhere to load one from — this app has no asset
/// catalogue and no icon file — and because the wave is the mark the release
/// icon is planned around, so the menu bar wears the same mark the app will.
/// Every one of them is a template image: black and nothing else, and the menu
/// bar decides what that means in the light and in the dark, over a wallpaper
/// and over a full-screen app, exactly as it does for every other icon up
/// there.
enum Icon {

    /// What a menu bar icon is given to draw in.
    private static let box = NSSize(width: 22, height: 22)

    /// One bar per step, round-robin, including the wrap back to frame zero.
    /// Four fps and a 0.45…0.70 range: visible, not an alert.
    private static let dance: [[CGFloat]] = [
        [0.45, 0.60, 0.50, 0.65],
        [0.55, 0.60, 0.50, 0.65],
        [0.55, 0.70, 0.50, 0.65],
        [0.55, 0.70, 0.60, 0.65],
        [0.55, 0.70, 0.60, 0.55],
        [0.45, 0.70, 0.60, 0.55],
        [0.45, 0.60, 0.60, 0.55],
        [0.45, 0.60, 0.50, 0.55],
    ]

    /// Not playing: the wave, which is the mark.
    static var still: NSImage {
        template { field in
            let path = NSBezierPath()
            let crests = 2.0
            let amplitude = field.height * 0.62 / 2
            // Forty-eight steps across: finer than any eye at twenty-two
            // points, and a polyline the menu bar never has to think about.
            let steps = 48
            path.move(to: CGPoint(x: field.minX, y: field.midY))
            for step in 1...steps {
                let along = Double(step) / Double(steps)
                let x = field.minX + field.width * CGFloat(along)
                let y = field.midY - CGFloat(sin(along * 2 * .pi * crests)) * amplitude
                path.line(to: CGPoint(x: x, y: y))
            }
            NSColor.black.setStroke()
            path.lineWidth = 1.8
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    /// Playing: the bars, at whichever frame of the dance this is. Frame nought
    /// is the one a player wears when it is playing and has been asked not to
    /// move — the Mac's Reduce Motion, or the dance switched off in Settings.
    static func playing(_ step: Int) -> NSImage {
        let heights = dance[abs(step) % dance.count]
        return template { field in
            NSColor.black.setFill()
            let bar: CGFloat = 2.6
            let gap: CGFloat = 2.2
            let span = CGFloat(heights.count) * bar + CGFloat(heights.count - 1) * gap
            var x = field.midX - span / 2
            for height in heights {
                let tall = max(2.6, field.height * height)
                let one = NSRect(x: x, y: field.midY - tall / 2, width: bar, height: tall)
                NSBezierPath(roundedRect: one, xRadius: bar / 2, yRadius: bar / 2).fill()
                x += bar + gap
            }
        }
    }

    /// One of the system's own shapes, for the menu's items: a menu is not the
    /// menu bar, and in a menu the shapes everybody knows are worth more than a
    /// mark of our own on every line of it.
    static func glyph(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    /// A template image with one thing drawn in it, in the field an icon has to
    /// draw in: the box with a little air round it, which is what keeps a
    /// stroke from being cropped by its own width. The drawing is the image's
    /// own and happens whenever the image is asked for, which is why it escapes
    /// this function rather than ending with it.
    private static func template(_ draw: @escaping (NSRect) -> Void) -> NSImage {
        let image = NSImage(size: box, flipped: false) { rect in
            draw(rect.insetBy(dx: 2.5, dy: 5))
            return true
        }
        image.isTemplate = true
        return image
    }
}
