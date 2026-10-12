import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The window: a row of small buttons, one line, and everywhere else somewhere
// to drop music on — with the cover of whatever is playing behind all of it,
// when the file has a cover to show. No toolbar, no sidebar, no list of what
// is queued: the queue is what was dropped, and it plays.
//
// Space plays and pauses from the moment the window opens, with nothing
// clicked and nothing focused (see `watchKeys`). Everything drawn here is what
// it is until the design waves dress it (P-06, P-07): the background is a
// blurred cover with a dark laid over it, and there is no glass in it and
// nothing about it glows.

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
        // The cover of whatever is playing, behind everything and never in
        // front of anything: a background in the strict sense, drawn under the
        // content and not clickable, so that neither the buttons nor the drop
        // know it is there.
        .background { backdrop }
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

    /// The window's background: the cover of the track that is playing,
    /// stretched over the whole window, blurred once on a queue of its own
    /// before it ever arrived here, and darkened so that the line at the foot
    /// stays readable over a sleeve that may be busy or bright.
    ///
    /// No cover, or one that would not decode, and nothing from the track is
    /// behind the content: only the dark underlay it has always had, with no
    /// substitute drawn in place of the missing cover. The blur is in the
    /// picture rather than in the drawing, so what happens here every frame is
    /// one small bitmap stretched: the same cheap work at any size of window,
    /// and none at all while nothing moves, which is what keeps a resize smooth
    /// and an idle player idle.
    private var backdrop: some View {
        ZStack {
            // What there is when a file has no sleeve to show, and what peeks
            // through the dark laid over one that has: a plain, dark window,
            // not a placeholder pretending to be a cover.
            Color(red: 0.04, green: 0.04, blue: 0.05)
            if let artwork = engine.artwork {
                ZStack {
                    Image(nsImage: artwork)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                    // The dark over it: enough that the line at the foot is
                    // read rather than decoded, and not enough to lose the
                    // colour that made the picture worth putting there.
                    Color.black.opacity(0.62)
                }
                // The window's own size, and not the picture's: a cover
                // stretched to fill is bigger than the window in one direction
                // or the other, and the part of it outside is left behind.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // One number, one fade: a cover arriving, being replaced by
                // the next track's, or going when the queue comes to an end,
                // is a change of the background and of nothing else here. A
                // third of a second of it, and no more — long enough that a
                // cover arriving is not a blink, short enough that the next
                // track is never waited for.
                .id(engine.artworkToken)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: engine.artworkToken)
        // A background is not something to click on, and a drop that lands on
        // it is a drop that lands on the window.
        .allowsHitTesting(false)
    }

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

    /// The foot of the window: the buttons, and the line that says what is
    /// playing.
    ///
    /// Two buttons were here before — to open something, and to start it or
    /// stop it for a while — and two more walk the queue in front of them,
    /// which is the other thing anyone ever asks of a player. At the far end,
    /// past the line, the two modes: how the queue is walked, and what happens
    /// when the walk comes to an end. Each of them is the accent while it is
    /// on and the quiet grey of everything else in the bar while it is not,
    /// which is all the "on" a bar this small needs — the shapes themselves
    /// come with the design waves.
    private var bar: some View {
        HStack(spacing: 10) {
            Button { engine.previous() } label: {
                Image(systemName: "backward.fill")
                    // A fixed width, so the symbols don't shuffle the row
                    // about as they swap.
                    .frame(width: 16)
            }
            .disabled(engine.count == 0)
            .help("Previous — the start of this track, once three seconds of it have gone by")
            .accessibilityLabel("Previous track")

            Button { engine.next() } label: {
                Image(systemName: "forward.fill")
                    .frame(width: 16)
            }
            .disabled(engine.count == 0)
            .help("Next track")
            .accessibilityLabel("Next track")

            Button { engine.toggle() } label: {
                Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
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

            Button { engine.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .frame(width: 16)
                    .foregroundStyle(engine.shuffle ? Color.accentColor : Color.secondary)
            }
            .help(engine.shuffle
                ? "Shuffled — click to walk the queue in the order it was opened"
                : "In order — click to shuffle the queue")
            .accessibilityLabel("Shuffle")
            .accessibilityValue(engine.shuffle ? "On" : "Off")

            Button { engine.cycleRepeat() } label: {
                // Two symbols for three states, because that is all there are:
                // off and the whole queue wear the same one, and the accent —
                // with the words in `repeatHelp` — is what tells them apart.
                Image(systemName: engine.repeatMode == .one ? "repeat.1" : "repeat")
                    .frame(width: 16)
                    .foregroundStyle(
                        engine.repeatMode == .off ? Color.secondary : Color.accentColor
                    )
            }
            .help(repeatHelp)
            .accessibilityLabel("Repeat")
            .accessibilityValue(repeatSaid)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    /// What the repeat button says about itself, which is the three states it
    /// walks through put into words: one of them is a different symbol, and
    /// the other two are only ever told apart here.
    private var repeatHelp: String {
        switch engine.repeatMode {
        case .off: return "Repeat off — the queue is walked once through"
        case .all: return "Repeat the queue — a new pass when one comes to an end"
        case .one: return "Repeat this track — until Next or Previous says otherwise"
        }
    }

    /// The same three states, for anyone listening rather than looking.
    private var repeatSaid: String {
        switch engine.repeatMode {
        case .off: return "Off"
        case .all: return "The whole queue"
        case .one: return "This track"
        }
    }

    /// The one line: what is playing, said the way a sleeve says it, and where
    /// the player is in the pass it is walking — or whatever the player has to
    /// say instead. Empty at the very start, where the middle of the window
    /// does the talking.
    private var line: String {
        if let note = engine.note { return note }
        guard let track = engine.track else { return "" }
        let verb = engine.state == .paused ? "Paused" : "Playing"
        return "\(verb) \(engine.number) of \(engine.count) — \(names(of: track))"
    }

    /// The track's names, of those its file has: who, then what, then the
    /// album it came out on — with the file's own name standing in for a title
    /// it never gave, which is what the line said before there was any reading
    /// of tags at all. So a tagged file says «Artist — Title — Album», a file
    /// with a title and nothing else says «Title», and a file with no tags at
    /// all says «track.mp3», exactly as it did before.
    ///
    /// The names are read on a queue of their own and arrive a moment after
    /// the track starts, so what is on screen a beat early is the filename —
    /// which is the fallback, and not a mistake.
    private func names(of track: URL) -> String {
        let said: [String?] = [engine.artist, engine.title ?? track.lastPathComponent, engine.album]
        return said.compactMap { $0 }.joined(separator: " — ")
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
