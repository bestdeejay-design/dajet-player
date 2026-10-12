import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The window: two small buttons, one line, and everywhere else somewhere to
// drop music on. No toolbar, no sidebar, no list of what is queued — the
// queue is what was dropped, in the order it was dropped, and it plays.
//
// Space plays and pauses from the moment the window opens, with nothing
// clicked and nothing focused (see `watchKeys`). Everything drawn here is what
// it is until the design waves dress it (P-06, P-07).

@main
struct DajetPlayerApp: App {
    /// The player, made once for the life of the app and handed to the window.
    /// The window is the only thing that holds it, and the only thing that can
    /// make a sound.
    @StateObject private var engine = PlayerEngine()

    var body: some Scene {
        Window("Dajet Player", id: "player") {
            PlayerView(engine: engine)
                // Something for the window to be at least, as the skeleton
                // had it: the player asks for no size of its own.
                .frame(minWidth: 520, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 560)
    }
}

/// The window, and everything in it.
struct PlayerView: View {
    @ObservedObject var engine: PlayerEngine

    /// The key monitor that gives the window Space, for as long as it is open.
    @State private var keys: Any?
    /// Something is being dragged over the window, and the middle of it says
    /// so while that lasts.
    @State private var taking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            middle
            Spacer(minLength: 0)
            bar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The window takes what the Finder can carry — a file, a folder, or a
        // handful of either — and nothing else: an address dragged in from a
        // browser is not a file URL, is not accepted, and never reaches the
        // player. Nothing here can play anything but a file on this Mac, which
        // is the whole of "no network requests" so far as this window goes.
        .onDrop(of: [.fileURL], isTargeted: $taking) { take($0) }
        .onAppear { watchKeys() }
        .onDisappear {
            if let keys { NSEvent.removeMonitor(keys) }
            keys = nil
        }
    }

    // MARK: - what is drawn

    /// The middle of the window, where there is nothing to look at: what it
    /// says while nothing has been opened, and what it says while music is
    /// being dragged in over it.
    @ViewBuilder
    private var middle: some View {
        Group {
            if taking {
                Text("Let go to play.")
            } else if fresh {
                Text("Drop a folder of music, or a few files — \(PlayerEngine.kinds).")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }

    /// Nothing has been opened yet: the middle of the window is where the
    /// invitation goes, and the line at the foot of it has nothing to say.
    private var fresh: Bool {
        engine.state == .idle && engine.count == 0 && engine.note == nil
    }

    /// The foot of the window: the two buttons, and the line that says what is
    /// playing. Two buttons, because two is all there is to ask of this
    /// player — to open something, and to start it or stop it for a while.
    private var bar: some View {
        HStack(spacing: 10) {
            Button { engine.toggle() } label: {
                Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    // A fixed width, so the two symbols don't shuffle the row
                    // about as they swap.
                    .frame(width: 16)
            }
            .disabled(engine.count == 0)
            .help(engine.state == .playing ? "Pause (Space)" : "Play (Space)")
            .accessibilityLabel(engine.state == .playing ? "Pause" : "Play")

            Button("Open Folder…") { choose() }
                .keyboardShortcut("o")
                .help("Play every track in a folder, in order")

            Spacer(minLength: 12)

            Text(line)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    /// The one line: what is playing, and where it sits in what was opened —
    /// or whatever the player has to say instead. Empty at the very start,
    /// where the middle of the window does the talking.
    private var line: String {
        if let note = engine.note { return note }
        guard let track = engine.track else { return "" }
        let verb = engine.state == .paused ? "Paused" : "Playing"
        return "\(verb) \(engine.number) of \(engine.count) — \(track.lastPathComponent)"
    }

    // MARK: - the two ways in

    /// The other way in, for anyone who would rather not drag: a folder of
    /// music. One file is quicker dragged in; a folder, and the album that is
    /// in it, is what a panel is good at.
    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Where music lives on an ordinary Mac, to save the walk there.
        panel.directoryURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
        panel.prompt = "Play"
        panel.message = "A folder of music: \(PlayerEngine.kinds)."
        guard panel.runModal() == .OK else { return }
        engine.open(panel.urls)
    }

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
        whole.notify(queue: .main) {
            MainActor.assumeIsolated { engine.open(found.urls) }
        }
        return true
    }

    // MARK: - the keyboard

    /// Space, anywhere in the window, from the moment it opens: nothing has to
    /// be clicked, and nothing has to have the keyboard for it. A view that
    /// asked SwiftUI for the key would be given it only while it was focused,
    /// and Space is the one key a player has to hear whatever else is going
    /// on. A local monitor hears it before anything else in this app does, and
    /// swallows it — so the button that happens to be focused isn't pressed
    /// along with it, and nothing beeps.
    private func watchKeys() {
        guard keys == nil else { return }
        let engine = engine
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Space is a space in the folder panel, not a pause: that panel is
            // this app's too, and its keys are its own.
            guard !(event.window is NSPanel) else { return event }
            // Bare space, and one press at a time: a modifier makes it another
            // key entirely, and a held key repeats — this one would start and
            // stop the music as fast as the keyboard could say so.
            let borrowed: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard event.charactersIgnoringModifiers == " ",
                  event.modifierFlags.isDisjoint(with: borrowed),
                  !event.isARepeat
            else { return event }
            MainActor.assumeIsolated { engine.toggle() }
            return nil
        }
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
