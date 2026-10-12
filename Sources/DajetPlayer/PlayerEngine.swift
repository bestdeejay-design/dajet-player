import AppKit
import AVFoundation
import Combine
import CoreGraphics
import CoreImage
import Foundation
import ImageIO

// The whole of the player: the files that were opened, the order they are
// walked in, what each of them says about itself, and what happens when one of
// them comes to an end. Everything the window knows about what is playing
// comes from here.
//
// One AVPlayer, one item at a time, replaced as each track ends. AVFoundation
// decodes every format on the list by itself, and every URL that reaches the
// player is a file on this Mac: nothing here is ever handed an address that
// could be somewhere else, which is what "not one network request" means in
// code rather than in a promise. A track's name and its cover are read out of
// the same file that is playing it — its own tags, on the disk it was dropped
// from — so there is nowhere else for that promise to be broken.
//
// The queue is what was opened, and it is never rewritten: the order it is
// walked in is a list of its places, straight through by default and shuffled
// when that is asked for, and turning shuffle off puts the places back in a
// line without so much as touching the track that is playing. Next and
// Previous walk the same list. The keyboard's media keys, the progress bar and
// the volume are a later wave (P-05).

/// The player, and everything it knows: where it is, what it is playing, what
/// the file being played says about itself, and what there is to say about any
/// of it.
///
/// All of it on the main thread, with one exception that is deliberate:
/// reading a file's tags and making a background out of its cover takes as
/// long as the disk and the picture take, which is not the main thread's
/// business and is done on one of its own (see `Sleeves`, at the foot of this
/// file). AVPlayer wants to be talked to from the thread it was made on, the
/// window reads this straight, and nothing left here takes long enough to be
/// worth a queue of its own: opening a folder is a listing, and starting a
/// track is a line of AVFoundation.
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

    /// What happens when the walk comes to an end. `off` ends it, as it did
    /// before there was anything to ask for; `all` starts the pass again from
    /// its first track; `one` never leaves the track it is on, until Next,
    /// Previous or this button itself says otherwise.
    enum Repeat: Equatable {
        case off
        case all
        case one
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
    /// Where the player is in the pass it is walking — "3 of 12". Zero with
    /// nothing playing; `count` is how many files were opened. Straight
    /// through, that is the same number it has always been; shuffled, it
    /// counts 1, 2, 3 along what will actually be heard rather than jumping
    /// about the places the files hold in what was opened.
    @Published private(set) var number = 0
    @Published private(set) var count = 0
    /// A line about anything but the track: nothing in what was opened is
    /// music, or the queue has played itself out. Cleared when something is
    /// opened and when a track starts.
    @Published private(set) var note: String?

    /// What the file says it is: its title, its artist and the album it came
    /// out on, read out of its own tags. Nil until the reading comes back, and
    /// nil afterwards too when the file says nothing — the window then calls
    /// the track by its filename, which is what the line said before there was
    /// any reading of tags at all.
    @Published private(set) var title: String?
    @Published private(set) var artist: String?
    @Published private(set) var album: String?

    /// The cover of the track that is playing: made small and blurred once, on
    /// a queue of its own, and ready to be stretched over the window and left
    /// alone for as long as that track plays. Nil when the file has no cover
    /// or one that will not decode, and the window is then the plain dark it
    /// has always been.
    @Published private(set) var artwork: NSImage?
    /// A number that goes up with every change of `artwork`, for the window to
    /// hang its fade on. The picture is a new object each time and the old one
    /// is gone by the time the new one arrives, so what a cross-fade wants is
    /// something that says "this is a different background now", and a count
    /// of them is exactly that.
    @Published private(set) var artworkToken = 0

    /// The two modes: how the queue is walked, and what happens when the walk
    /// comes to an end. Both are asked for by clicking, and neither is ever
    /// reason to interrupt the track that is playing.
    @Published private(set) var shuffle = false
    @Published private(set) var repeatMode: Repeat = .off

    // MARK: - what it is doing

    /// The one player. Everything the window can hear comes out of it.
    private let player = AVPlayer()
    /// What was opened, in the order it arrived. Never rewritten, never
    /// reordered: this is the list the window's "of 12" counts, and the one a
    /// dropped folder became.
    private var queue: [URL] = []
    /// The order the pass is walked in: every place in `queue`, each of them
    /// exactly once. Straight through it is 0, 1, 2…; shuffled it is the same
    /// numbers in an order nobody could guess. Keeping it beside the queue
    /// rather than in it is what lets shuffle be turned off again without
    /// anything having been lost.
    private var order: [Int] = []
    /// Where the player is in `order`. -1 when nothing is playing.
    private var place = -1
    /// The place in `queue` of the track that is playing, wherever this pass
    /// happens to be walking it. -1 with nothing playing.
    private var at: Int { order.indices.contains(place) ? order[place] : -1 }
    /// The files of this pass that would not open. A set, rather than a count,
    /// because changing the order makes a new pass with the same files in it,
    /// and a broken file tried twice is still one broken file. What keeps a
    /// folder of files that are not what their names claim from being walked
    /// for ever is how many different ones have gone this way, and that starts
    /// again with every pass.
    private var failed: Set<Int> = []
    /// What the files have said about themselves so far, minus their covers:
    /// three words apiece for every track played, which is nothing at all in
    /// memory, where a blurred picture for every track in a folder would be a
    /// great deal of it held for tracks that are not playing. Kept for as long
    /// as the queue is, so that going back to a track says its name at once.
    private var said: [URL: Sleeve] = [:]
    /// How many tracks have been started since the queue was opened. A reading
    /// that comes back with a number older than this one came back for a track
    /// that is no longer playing, and is dropped where it stands.
    private var started = 0
    /// The reading that is on its way, if one is. Cancelled by the next.
    private var reading: Task<Void, Never>?
    /// What the item on the player has to say: that it won't play, that it has
    /// played itself out, that it broke on the way. All of it is let go of
    /// when the item is replaced.
    private var watching: [NSKeyValueObservation] = []
    private var notices: [NSObjectProtocol] = []

    // MARK: - opening

    /// What was dropped or chosen, in the order it arrived: folders are read
    /// for the music in them, everything found becomes the queue, and the
    /// first track of the pass starts at once — the first track of a shuffled
    /// pass being wherever the shuffle put it. What was playing is let go of,
    /// and what the last queue said about itself with it: one gesture, one
    /// queue. The two modes are left as the listener set them, so that dropping
    /// a second folder on a player that was told to shuffle gives a shuffled
    /// folder.
    func open(_ urls: [URL]) {
        let files = urls.flatMap(music)
        guard !files.isEmpty else {
            forget()
            note = Self.nothingPlays
            return
        }
        queue = files
        count = files.count
        said = [:]
        newPass()
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

    // MARK: - the buttons

    /// What Space does, whenever it is pressed: play, wait, go on — and with
    /// nothing playing, what was opened last starts again from the beginning
    /// of a pass.
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
            // A new time round: the order is drawn again — shuffled afresh,
            // when shuffling is what was asked for — what would not open last
            // time is tried again, and the count of it starts again from
            // nothing.
            newPass()
            play(0)
        }
    }

    /// The next track, and what the forward button does. From a pause it
    /// switches the track and stays paused; with nothing playing it starts a
    /// pass from its first track, as Space does. On the last track of a pass
    /// it does whatever the mode says is done at an end: nothing, or a new
    /// pass.
    func next() {
        guard !queue.isEmpty else { return }
        switch state {
        case .playing:
            advance()
        case .paused:
            advance(sounding: false)
        case .idle:
            newPass()
            play(0)
        }
    }

    /// The track before, and what the backward button does. Three seconds into
    /// a track, and back means "again from the top" — one press for the
    /// beginning of this track, a second for the one before it, which is what
    /// every listener expects of the button. Inside three seconds it goes back
    /// a track; on the first track of the pass it starts this one over rather
    /// than jumping to the end of the queue; from a pause it switches and
    /// stays paused; and with nothing playing it starts a pass, as Next does.
    func previous() {
        guard !queue.isEmpty else { return }
        switch state {
        case .playing:
            back()
        case .paused:
            back(sounding: false)
        case .idle:
            newPass()
            play(0)
        }
    }

    /// Shuffle, on and off. The track that is playing is not touched — nothing
    /// here goes near the player at all. On, and the whole queue is shuffled
    /// afresh with this track put at the head of the new order, so that it
    /// goes on playing and every track after it is heard exactly once; off,
    /// and the order is the queue's own again, with this track left where it
    /// sits in it, so that what follows is the file that comes after it in
    /// what was opened. Either way the number on the line follows the track
    /// into its new place.
    func toggleShuffle() {
        // Read before the order changes underneath it.
        let here = at
        shuffle.toggle()
        guard !queue.isEmpty else { return }
        if shuffle {
            var drawn = Self.shuffled(count)
            if here >= 0, let was = drawn.firstIndex(of: here) {
                drawn.remove(at: was)
                drawn.insert(here, at: 0)
            }
            order = drawn
            place = here >= 0 ? 0 : place
        } else {
            order = Array(0..<count)
            place = here >= 0 ? here : place
        }
        // A changed order is a new pass: files that failed in the old one may
        // be somewhere in this order again, and each is counted once here.
        failed = []
        if place >= 0 { number = place + 1 }
    }

    /// Repeat, round and round the three of them: off, then the whole queue,
    /// then the one track, then off again. The track that is playing goes on
    /// playing whatever the mode becomes — what a mode decides is only what
    /// happens when a track, or a pass, comes to its end.
    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - playing

    /// The track at that place in the order, from its beginning. What was
    /// playing is let go of first: its observations, its end-of-track notice,
    /// and the item itself.
    ///
    /// Whether the sound follows at once is the caller's business: a track
    /// switched to from a pause is loaded and left paused, and is heard when
    /// Space is pressed again.
    private func play(_ place: Int, sounding: Bool = true) {
        guard order.indices.contains(place) else { return done() }
        let index = order[place]
        guard queue.indices.contains(index) else { return done() }
        let url = queue[index]
        let item = AVPlayerItem(url: url)
        self.place = place
        track = url
        number = place + 1
        note = nil
        sleeve(url)
        watch(item)
        if sounding {
            player.replaceCurrentItem(with: item)
            player.play()
            state = .playing
        } else {
            // Paused before the item goes in, rather than after: a player that
            // is playing keeps playing whatever is handed to it, and a track
            // switched to from a pause is not meant to be heard on the way.
            player.pause()
            player.replaceCurrentItem(with: item)
            state = .paused
        }
    }

    /// One step along the order, and what the mode says there is to do when
    /// the order comes to its end: nothing at all with repeat off, and a new
    /// pass — shuffled afresh, when that is the order of the day — with either
    /// of the repeats on.
    private func advance(sounding: Bool = true, keepCurrentFirst: Bool = false) {
        if order.indices.contains(place + 1) {
            play(place + 1, sounding: sounding)
        } else if repeatMode == .off {
            done()
        } else {
            // The pass is over and the listener has asked for it to come
            // round again: a new one, drawn afresh, and its first track. At
            // the natural end of a shuffled pass, this track is put first —
            // the same promise made when shuffle was turned on halfway through
            // a track, that the track at the turn keeps its place.
            newPass(startingWith: keepCurrentFirst ? at : nil)
            play(0, sounding: sounding)
        }
    }

    /// One step back along the order: the start of this track once three
    /// seconds of it have gone by, the track before it otherwise, and the
    /// start of this track again on the first one, where there is nothing
    /// before it to go back to.
    private func back(sounding: Bool = true) {
        // What the player has played of the item that is on. Non-numeric —
        // before the item has got itself together — counts as no time at all,
        // which sends the button back a track rather than to a beginning it
        // has already left.
        let heard = player.currentTime()
        if heard.isNumeric, heard.seconds > 3 {
            return replay(sounding: sounding)
        }
        guard place > 0 else { return replay(sounding: sounding) }
        play(place - 1, sounding: sounding)
    }

    /// The track that is on, from its beginning again — for repeat-one when a
    /// track plays itself out, and for Previous when that is what back means.
    /// The item stays the item it is: nothing is read again and nothing is
    /// drawn again, so the window does not blink once a track for a track that
    /// has not changed.
    private func replay(sounding: Bool = true) {
        guard order.indices.contains(place) else { return done() }
        guard let item = player.currentItem else { return play(place, sounding: sounding) }
        item.seek(to: .zero)
        if sounding {
            player.play()
            state = .playing
        } else {
            player.pause()
            state = .paused
        }
    }

    /// A new pass through the queue: the places in a line again, or shuffled
    /// afresh. A shuffled pass is a different walk every time, which is the
    /// whole of what shuffle means, and what keeps one ordering from being
    /// heard over and over for as long as the player is left to itself. At the
    /// natural end of a shuffled pass, the track that just ended is the first
    /// of the new one; nowhere else does a new pass have a track already
    /// chosen for its head. With it goes the count of files that would not
    /// open, which is a count of this pass and not of the queue.
    private func newPass(startingWith first: Int? = nil) {
        var drawn = shuffle ? Self.shuffled(count) : Array(0..<count)
        if shuffle, let first, let was = drawn.firstIndex(of: first) {
            drawn.remove(at: was)
            drawn.insert(first, at: 0)
        }
        order = drawn
        failed = []
    }

    /// Every number from zero to one under `count`, each of them exactly once,
    /// in an order nobody could guess: Fisher–Yates, walking the list from its
    /// end and swapping each place with one of the places up to and including
    /// itself. That is the shuffle which leaves every ordering equally likely,
    /// and it is what "no track twice in a pass" means in code — there is
    /// nothing in the list to be drawn twice, because nothing is ever put back.
    private static func shuffled(_ count: Int) -> [Int] {
        var order = Array(0..<count)
        guard count > 1 else { return order }
        for place in stride(from: count - 1, through: 1, by: -1) {
            order.swapAt(place, Int.random(in: 0...place))
        }
        return order
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
                MainActor.assumeIsolated { self?.ended() }
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

    /// The end of a track. With repeat-one it is not an end at all: the same
    /// track starts again from its beginning. Otherwise the walk goes on, and
    /// what happens at the end of the order is the mode's business.
    private func ended() {
        guard order.indices.contains(place) else { return done() }
        guard repeatMode != .one else { return replay() }
        advance(keepCurrentFirst: repeatMode == .all && shuffle)
    }

    /// A file that would not open, or one that started and broke. Passed over
    /// for the next one, with a count kept of how many have gone this way: the
    /// pass is walked once and not again, however many of its files turn out
    /// not to be music. A track that will not play is not a track to repeat,
    /// so repeat-one is no exception — the walk goes on, and the player never
    /// sits silent on a file it cannot open.
    private func skip(_ item: AVPlayerItem) {
        // Whatever an item says is only its own business while it is the one
        // playing: an item replaced a moment ago says nothing about what is on
        // now.
        guard item === player.currentItem, order.indices.contains(place) else { return }
        failed.insert(at)
        guard failed.count < count else {
            forget()
            note = Self.nothingPlays
            return
        }
        // Passed over in whatever state the listener left the player in: a
        // queue walked while paused stays paused, and does not start making
        // sound halfway along.
        advance(sounding: state == .playing)
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
        order = []
        count = 0
        failed = []
        said = [:]
        note = nil
    }

    /// Nothing playing any more: the item let go of, and with it everything
    /// that was listening to it — including whatever was on its way back from
    /// the disk about a track that is no longer playing.
    private func stop() {
        unfollow()
        reading?.cancel()
        reading = nil
        player.replaceCurrentItem(with: nil)
        state = .idle
        place = -1
        track = nil
        number = 0
        title = nil
        artist = nil
        album = nil
        artwork = nil
        artworkToken += 1
    }

    // MARK: - what a file says about itself

    /// The names and the cover of one file, asked for on a queue of their own.
    ///
    /// Whatever is already known is said at once, so that going back to a
    /// track played a moment ago does not flash its filename on the way to its
    /// real name. The cover is left where it is until the new one is ready, so
    /// that one track's background fades into the next and there is never a
    /// blink of the dark between them. A track started after this one has a
    /// reading of its own, and the count of starts is what tells a late answer
    /// that it is late: the window must never say the name of the track
    /// before.
    private func sleeve(_ url: URL) {
        started += 1
        let wanted = started
        let known = said[url]
        if let known {
            title = known.title
            artist = known.artist
            album = known.album
        } else {
            title = nil
            artist = nil
            album = nil
        }
        reading?.cancel()
        reading = Task.detached(priority: .userInitiated) { [weak self] in
            let found = await Sleeves.read(url, keeping: known)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                // A reading that comes back for a track that is no longer the
                // one playing — because the next one started while it was on
                // its way, or because the queue came to an end — is a reading
                // that came too late, and is dropped where it stands.
                guard let self, wanted == self.started, self.track == url else { return }
                self.keep(found, of: url)
            }
        }
    }

    /// What a reading came back with, and the last word on the track it was
    /// asked about: the names for the line, the picture for the background,
    /// and the names kept for the next time this track is played.
    private func keep(_ sleeve: Sleeve, of url: URL) {
        title = sleeve.title
        artist = sleeve.artist
        album = sleeve.album
        // Kept without its picture, for the reason given where it is stored.
        var kept = sleeve
        kept.artwork = nil
        said[url] = kept
        // AppKit's image is made here, on the main thread; the immutable
        // bitmap was made and blurred on the queue that read the file.
        artwork = sleeve.artwork.map {
            NSImage(cgImage: $0, size: CGSize(width: CGFloat($0.width), height: CGFloat($0.height)))
        }
        // The picture, whether there is one or not: a track with a cover of
        // its own fades the last one out from under it, and a track with none
        // fades the background away and leaves the window the dark it was.
        artworkToken += 1
    }
}

/// What one file says about itself: the three names in its tags, and the
/// picture on its sleeve — already made small and blurred, and ready to be a
/// background.
///
/// `@unchecked Sendable` because this whole reading, including its immutable
/// Core Graphics bitmap, is handed from the queue that made it to the main
/// thread once, and nothing writes to it afterwards.
private struct Sleeve: @unchecked Sendable {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: CGImage?
}

/// The reading of a file's tags, and the making of its cover into a
/// background: both of them away from the main thread, both of them out of the
/// file that was opened and nowhere else.
///
/// The reading is AVFoundation's own — `load` asks for a value and comes back
/// with it when the disk has found it, which is why none of this is on the
/// main thread and why nothing here waits for anything.
private enum Sleeves {

    /// The longest side of the picture that is made. A cover is a few hundred
    /// pixels to begin with, and what the window wants of it is a wash of
    /// colour behind everything, so there is nothing to be had by blurring a
    /// bigger one: this bounds the work whatever a file happens to hold, and
    /// stretching a small picture costs the same at any size of window.
    private static let side: CGFloat = 640

    /// How soft, in the small picture — and stretched with it, so what the
    /// window gets is two or three times this: enough to lose every edge in
    /// the cover and keep every colour of it.
    private static let softness: CGFloat = 14

    /// Core Image contexts are made for reuse and are safe to use from more
    /// than one queue. The wrapper says so to Swift's concurrency checker, too:
    /// the context is made once, then only asked to render immutable bitmaps.
    private final class Renderer: @unchecked Sendable {
        let context = CIContext()
    }
    private static let renderer = Renderer()

    /// What this file has to say about itself. Nothing is thrown and nothing
    /// is reported: a file that says nothing is a file whose name the window
    /// will show instead, and a cover that will not decode is a window that
    /// stays the dark it was. If the names are already known, they are kept
    /// while the cover is read again; the text tags are not read twice.
    static func read(_ url: URL, keeping known: Sleeve?) async -> Sleeve {
        var sleeve = known ?? Sleeve()
        let asset = AVURLAsset(url: url)
        // The tags of the file itself: ID3 in an mp3, the atoms of an m4a,
        // whatever a flac or a wav keeps. The URL is the one that was opened —
        // a file on this Mac — and there is no other kind anywhere in here.
        guard let items = try? await asset.load(.commonMetadata), !Task.isCancelled else {
            return sleeve
        }
        for item in items {
            guard !Task.isCancelled else { return sleeve }
            // The key is known the moment the item is, and asking for it costs
            // nothing; the values are what the disk is read for, and they are
            // asked of one at a time. The first item to have a value for a key
            // is the one kept: a file can say the same thing twice, in two key
            // spaces, and saying it twice is not saying it better.
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if known == nil, sleeve.title == nil {
                    sleeve.title = name(try? await item.load(.stringValue))
                }
            case .commonKeyArtist:
                if known == nil, sleeve.artist == nil {
                    sleeve.artist = name(try? await item.load(.stringValue))
                }
            // The album, as AVFoundation spells it.
            case .commonKeyAlbumName:
                if known == nil, sleeve.album == nil {
                    sleeve.album = name(try? await item.load(.stringValue))
                }
            case .commonKeyArtwork:
                if sleeve.artwork == nil, let data = try? await item.load(.dataValue) {
                    sleeve.artwork = backdrop(data)
                }
            default:
                continue
            }
        }
        return sleeve
    }

    /// A name worth saying: what the tag holds with the space taken off both
    /// ends, and nothing at all if that leaves nothing. A tag that is there
    /// but empty is a file saying nothing, and the window should call the
    /// track by its filename rather than print a gap.
    private static func name(_ string: String?) -> String? {
        guard let name = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    /// The cover as a background: drawn down, blurred once, and never touched
    /// again.
    ///
    /// What the window does with the result is stretch one small bitmap, which
    /// is the same cheap work whatever the size of the window and no work at
    /// all while the window is left alone — so the blur is here, once for the
    /// whole life of a track, rather than something the drawing does every
    /// frame.
    private static func backdrop(_ data: Data) -> CGImage? {
        // ImageIO makes a thumbnail straight from the file's data, instead of
        // first decoding a needlessly enormous cover and shrinking it after.
        // The largest bitmap Core Image ever sees is 640 pixels on a side.
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(side),
        ]
        guard let sourceFile = CGImageSourceCreateWithData(data as CFData, nil),
              let source = CGImageSourceCreateThumbnailAtIndex(
                sourceFile, 0, options as CFDictionary
              ),
              source.width > 0, source.height > 0 else { return nil }
        let sourceImage = CIImage(cgImage: source)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        // Held out past its own edges first, so that what the blur smears into
        // the borders is the picture, and not a transparency that would leave
        // a pale frame all the way round the window.
        filter.setValue(sourceImage.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(softness, forKey: kCIInputRadiusKey)
        guard let blurred = filter.outputImage,
              let ready = renderer.context.createCGImage(
                blurred, from: sourceImage.extent
              ) else { return nil }
        return ready
    }
}
