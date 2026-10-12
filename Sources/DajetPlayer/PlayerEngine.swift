import AVFoundation
import Combine
import Foundation

// The whole of the player: the files that were opened, in the order they
// arrived, one after another. Everything the window knows about what is
// playing comes from here.
//
// One AVPlayer, one item at a time, replaced as each track ends. AVFoundation
// decodes every format on the list by itself, and every URL that reaches the
// player is a file on this Mac: nothing here is ever handed an address that
// could be somewhere else, which is what "not one network request" means in
// code rather than in a promise.
//
// The queue is what was opened, and nothing else: a folder is read for the
// music in it, one track follows the last without being asked, and the two
// things that can be asked of the player are to start and to wait. Next and
// Previous, what a track is called, what its cover looks like, the keyboard's
// media keys: later waves (P-04, P-05).

/// The player, and everything it knows: where it is, what it is playing, and
/// what there is to say about either.
///
/// All of it on the main thread. AVPlayer wants to be talked to from the
/// thread it was made on, the window reads this straight, and nothing here
/// takes long enough to be worth a queue of its own: opening a folder is a
/// listing, and starting a track is a line of AVFoundation.
@MainActor
final class PlayerEngine: ObservableObject {

    /// What the window shows, and what Space switches between. `idle` is both
    /// ends of the player's life: before anything has been opened, and after
    /// the last track has played out — the queue stays where it is then, so
    /// Space can play it again from the top.
    enum State: Equatable {
        case idle
        case playing
        case paused
    }

    /// What plays. AVFoundation decodes every one of them — mp3, AAC in an
    /// m4a, flac, wav, aiff — and the same list is what a folder is read with,
    /// so the cover art and the sleeve notes sitting beside the music are
    /// passed over without a word. (`aif` is the same format as `aiff`,
    /// spelled shorter, and plays because it is the same decoder.)
    static let formats: Set<String> = ["mp3", "m4a", "flac", "wav", "aiff", "aif"]

    /// The same formats as the window names them, in one place, so that the
    /// invitation to drop something and the complaint when it isn't music
    /// can't drift apart.
    static let kinds = "mp3, m4a, flac, wav and aiff"

    /// Said when nothing that was opened can be played: a folder with no music
    /// in it, a file of some other kind, or a file whose name lies about what
    /// it holds. One sentence for all three — whoever dropped a folder of
    /// photographs and whoever dropped a broken mp3 want the same thing said,
    /// and neither cares which of the three they did.
    private static var nothingPlays: String { "Nothing there to play — \(kinds) only." }

    // MARK: - what the window reads

    @Published private(set) var state: State = .idle
    /// The file playing now, or the one Space would start.
    @Published private(set) var track: URL?
    /// Where that file sits in what was opened — "3 of 12". Zero with nothing
    /// playing; `count` is how many files were opened.
    @Published private(set) var number = 0
    @Published private(set) var count = 0
    /// A line about anything but the track: nothing in what was opened is
    /// music, or the queue has played itself out. Cleared when something is
    /// opened and when a track starts.
    @Published private(set) var note: String?

    // MARK: - what it is doing

    /// The one player. Everything the window can hear comes out of it.
    private let player = AVPlayer()
    /// What was opened, in playing order, and where in it the player is. `at`
    /// is -1 when nothing is playing.
    private var queue: [URL] = []
    private var at = -1
    /// How many files of the queue have been passed over this time round,
    /// because they would not open. The count is what keeps a folder of files
    /// that are not what their names claim from being walked for ever.
    private var failed = 0
    /// What the item on the player has to say: that it won't play, that it has
    /// played itself out, that it broke on the way. All of it is let go of
    /// when the item is replaced.
    private var watching: [NSKeyValueObservation] = []
    private var notices: [NSObjectProtocol] = []

    // MARK: - opening

    /// What was dropped or chosen, in the order it arrived: folders are read
    /// for the music in them, everything found becomes the queue, and the
    /// first track starts at once. What was playing is let go of — one
    /// gesture, one queue.
    func open(_ urls: [URL]) {
        let files = urls.flatMap(music)
        guard !files.isEmpty else {
            forget()
            note = Self.nothingPlays
            return
        }
        queue = files
        count = files.count
        failed = 0
        play(0)
    }

    /// The music in one thing that was dropped: the file itself, if it is one
    /// of the formats; every file in it, if it is a folder — read once, in the
    /// order the Finder lists them, so numbers in names are compared as
    /// numbers and "Track 2" comes before "Track 10". A folder is not walked
    /// into: what is in a folder is an album, and a library is opened by
    /// dropping the album wanted out of it.
    private func music(_ url: URL) -> [URL] {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
            return []   // Nothing there by that name any more.
        }
        guard values.isDirectory == true else { return playable(url) ? [url] : [] }
        let inside = (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return inside
            .filter { playable($0) }
            // A folder can be called anything, an .mp3 included. What is not
            // a file is not a track, whatever it is named.
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    /// Whether this is a file of a kind that plays.
    private func playable(_ url: URL) -> Bool {
        Self.formats.contains(url.pathExtension.lowercased())
    }

    // MARK: - playing

    /// What Space does, whenever it is pressed: play, wait, go on — and with
    /// nothing playing, what was opened last starts again from its first
    /// track.
    func toggle() {
        switch state {
        case .playing:
            player.pause()
            state = .paused
        case .paused:
            player.play()
            state = .playing
        case .idle:
            guard !queue.isEmpty else { return }
            // A new time round: what would not open last time is tried again,
            // and counted again from the start.
            failed = 0
            play(0)
        }
    }

    /// The track at that place in the queue, from its beginning, now. What was
    /// playing is let go of first: its observations, its end-of-track notice,
    /// and the item itself.
    private func play(_ index: Int) {
        guard queue.indices.contains(index) else { return done() }
        let item = AVPlayerItem(url: queue[index])
        at = index
        track = queue[index]
        number = index + 1
        note = nil
        watch(item)
        player.replaceCurrentItem(with: item)
        player.play()
        state = .playing
    }

    /// The three things an item has to say, and the only three: it will not
    /// play — a file that is not what its name says, or one this Mac cannot
    /// read — it has played itself out, and it started and then broke on the
    /// way, which is news of its own and is treated as one more file that
    /// would not open.
    private func watch(_ item: AVPlayerItem) {
        unfollow()
        watching = [
            item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard item.status == .failed else { return }
                // KVO says nothing about which thread its news arrives on, and
                // the player is talked to from the main one, so it is taken
                // there.
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.skip(item) }
                }
            }
        ]
        notices = [
            NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.next() }
            },
            NotificationCenter.default.addObserver(
                forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.skip(item) }
            },
        ]
    }

    /// Stop listening to the item that is on its way out: a replaced item has
    /// nothing left to say, and the notification centre would keep it — and
    /// every notice about it — for as long as they are registered.
    private func unfollow() {
        for one in watching { one.invalidate() }
        watching = []
        for notice in notices { NotificationCenter.default.removeObserver(notice) }
        notices = []
    }

    /// The end of a track: the next one, or the end of the queue.
    private func next() {
        guard queue.indices.contains(at + 1) else { return done() }
        play(at + 1)
    }

    /// A file that would not open, or one that started and broke. Passed over
    /// for the next one, with a count kept of how many have gone this way: the
    /// queue is walked once and not again, however many of its files turn out
    /// not to be music.
    private func skip(_ item: AVPlayerItem) {
        // Whatever an item says is only its own business while it is the one
        // playing: an item replaced a moment ago says nothing about what is on
        // now.
        guard item === player.currentItem, queue.indices.contains(at) else { return }
        failed += 1
        guard failed < count else {
            forget()
            note = Self.nothingPlays
            return
        }
        guard queue.indices.contains(at + 1) else { return done() }
        play(at + 1)
    }

    /// The queue has played out. Nothing is playing, and nothing is forgotten:
    /// what was opened stays, so that Space can play it again from the top.
    private func done() {
        stop()
        note = "That was the last one — Space starts again from the top."
    }

    /// Let go of everything: nothing playing, and nothing left to play.
    private func forget() {
        stop()
        queue = []
        count = 0
        failed = 0
        note = nil
    }

    /// Nothing playing any more: the item let go of, and with it everything
    /// that was listening to it.
    private func stop() {
        unfollow()
        player.replaceCurrentItem(with: nil)
        state = .idle
        at = -1
        track = nil
        number = 0
    }
}
