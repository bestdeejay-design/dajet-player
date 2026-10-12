import AppKit
import SwiftUI
import UniformTypeIdentifiers

// The window: a row of small buttons, one line, how loud it is, a thin bar
// along the foot saying how far into the track the player is, and everywhere
// else somewhere to drop music on — with the cover of whatever is playing
// behind all of it, when the file has a cover to show. No toolbar, no
// sidebar, no list of what is queued: the queue is what was dropped, and it
// plays.
//
// Space plays and pauses from the moment the window opens, with nothing
// clicked and nothing focused, and the two arrows walk the queue beside it
// (see `watchKeys`). Everything drawn here is what it is until the design
// waves dress it (P-06, P-07): the background is a blurred cover with a dark
// laid over it, and there is no glass in it and nothing about it glows.

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

    /// The key monitor that gives the window Space and the two arrows, for as
    /// long as it is open.
    @State private var keys: Any?
    /// Something is being dragged over the window, and the middle of it says
    /// so while that lasts.
    @State private var taking = false
    /// Where a hand has the progress bar, in seconds into the track, while it
    /// is on it. Nothing at all when nobody is touching it — the bar then
    /// shows the player's own place, which is the whole point of it.
    @State private var scrubbing: TimeInterval?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            middle
            Spacer(minLength: 0)
            bar
            // The very foot of the window, and nothing at all until there is a
            // queue: with nothing opened there is no track, no length and
            // nowhere to take anything to, and a bar with nothing to say is
            // not drawn.
            if engine.count > 0 { progress }
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

    /// The thin bar along the foot of the window: how far into the track the
    /// player is, and where a hand can take it to. No numbers — the line is
    /// the whole of what it says, which is what a player this quiet wants of a
    /// bar.
    ///
    /// While a hand is on it the line follows the hand and the music does not
    /// move one bit: a drag that dragged the sound along would stutter the
    /// track through every place the thumb passed. Let go, and the track is
    /// taken to that place (see the engine's `seek`), playing or paused as it
    /// was. A plain click is the same thing — a drag of no length, let go of
    /// at once.
    private var progress: some View {
        GeometryReader { room in
            ZStack(alignment: .bottomLeading) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.12))
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: room.size.width * filled)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 3)
            }
            // The line is thin; the place to put a hand on it is not: the
            // whole strip answers the drag, and the line is drawn at the foot
            // of it.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .contentShape(Rectangle())
            .gesture(hold(along: room.size.width))
        }
        .frame(height: 11)
        // Nowhere to take the track and there is nothing to drag: a track
        // whose file has not said how long it is leaves the bar drawn but
        // still, rather than one that jumps about over a length nobody knows.
        .opacity(scrubbable ? 1 : 0.35)
        .allowsHitTesting(scrubbable)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((filled * 100).rounded())) percent")
    }

    /// How far into the track the bar draws itself, from nought to one: where
    /// a hand has it while one is on it, and where the player is otherwise.
    private var filled: Double {
        let span = engine.duration
        guard span > 0 else { return 0 }
        return min(max((scrubbing ?? engine.position) / span, 0), 1)
    }

    /// Whether there is anywhere on the bar to take the track to: something
    /// playing or waiting, and a file that has said how long it is.
    private var scrubbable: Bool {
        engine.duration > 0 && engine.state != .idle
    }

    /// The hand on the bar. Barely any movement is a drag as well — a
    /// `minimumDistance` of nothing — so that a click on the bar is a click on
    /// a place in the track, which is what anyone clicking a bar means.
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

    /// Where on the bar a hand is, said in seconds into the track.
    private func seconds(at x: CGFloat, along width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return min(max(x / width, 0), 1) * engine.duration
    }

    /// The foot of the window: the buttons, and the line that says what is
    /// playing, how loud it is, and where the player can be taken.
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

            // How loud, and whether at all: the volume is the player's own
            // and is remembered between runs, and the mute stands beside it
            // rather than being a volume of nought — the button gives back the
            // volume the slider is at, whatever that was.
            Button { engine.toggleMute() } label: {
                Image(systemName: engine.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 16)
                    .foregroundStyle(engine.muted ? Color.accentColor : Color.secondary)
            }
            .help(engine.muted ? "Muted — click to hear it again" : "Mute")
            .accessibilityLabel("Mute")
            .accessibilityValue(engine.muted ? "On" : "Off")

            Slider(value: loudness, in: 0...1)
                .frame(width: 72)
                .controlSize(.small)
                .help("Volume — remembered between runs")
                .accessibilityLabel("Volume")

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

    /// The volume slider's two directions: where the player is, and where a
    /// hand dragging it asks the player to be. The engine owns the volume —
    /// it is the thing that is heard, and the thing that remembers.
    private var loudness: Binding<Float> {
        Binding(get: { engine.volume }, set: { engine.setVolume($0) })
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

    /// The three keys the player takes from the keyboard — Space and the two
    /// arrows — anywhere in the window, from the moment it opens: nothing has
    /// to be clicked, and nothing has to have the keyboard for it. A view that
    /// asked SwiftUI for a key would be given it only while it was focused,
    /// and these are the keys a player has to hear whatever else is going on.
    /// A local monitor hears them before anything else in this app does, and
    /// swallows them — so the button that happens to be focused isn't pressed
    /// along with them, and nothing beeps.
    ///
    /// The keys are told apart by their code rather than by the characters
    /// they would have made, because these three are places on the keyboard
    /// and not letters: a layout that moves the letters about leaves space
    /// where it was, the left arrow on the left and the right one on the
    /// right. Up and down are left alone — they are the system's, and this app
    /// has nothing to say about them. The Mac's own media keys are not here
    /// and never will be: the system hands those to the app through
    /// `MPRemoteCommandCenter` (the engine's business), and a second monitor
    /// listening for them would be a second way to play the same thing.
    private func watchKeys() {
        guard keys == nil else { return }
        let engine = engine
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Nothing here is a key in the folder panel: that panel is this
            // app's too, and its keys are its own.
            guard !(event.window is NSPanel) else { return event }
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
