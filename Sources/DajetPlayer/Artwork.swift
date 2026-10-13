import CoreGraphics
import Foundation

// What a file says about itself when AVFoundation has nothing to say, and what
// the folder beside it says instead.
//
// AVFoundation reads the tags of an mp3 (ID3v2) and of an m4a (the atoms of
// the container) — titles, artists, albums and the cover in them — and for
// those two this file has nothing to add. What it does not read on macOS is a
// FLAC: a FLAC keeps its words in a Vorbis comment block and its cover in a
// PICTURE block of its own, both of them ahead of the first frame of audio and
// neither of them in a key space AVFoundation reports. Finder shows no
// thumbnail for such a file either, and for the same reason. So the blocks are
// read here, out of the file's own bytes, with nothing but Foundation: the
// format's own layout is a marker, then block after block of a kind and a
// length, and that is the whole of what it takes.
//
// The same reading picks up an ID3v2 tag worn *in front of* another format,
// which is how a great many FLAC files are tagged in practice — it is what
// makes Finder show their covers — and the only way a wav or an aiff carries
// one at all. So the head of the file is asked in this order: an ID3v2 tag,
// then the FLAC marker and its blocks, then, with nothing found, the folder.
//
// The folder is the second half of what a cover can be: a picture lying beside
// the music, called cover.jpg or folder.jpg or one of a handful of other
// names, which is how an album is kept when its files carry no picture of
// their own. Embedded first and the sidecar second, because a picture in the
// file is the file's own word about itself and a picture beside it is the
// folder's.
//
// Everything here reads a file on this Mac and nothing else. There is no
// address anywhere in this file and no way for one to arrive: a cover is
// either in the track, or beside it, or it does not exist.

/// What one file's own bytes said: three names and a picture, each of them
/// optional, none of them ever fetched from anywhere but the disk.
struct TagReading {
    var title: String?
    var artist: String?
    var album: String?
    /// The cover as the file holds it — the encoded bytes, not a bitmap. What
    /// is done with them (a thumbnail, a blur) is the caller's business, and
    /// is ImageIO's rather than this file's.
    var picture: Data?

    /// Whether there was nothing to say at all.
    var isEmpty: Bool {
        title == nil && artist == nil && album == nil && picture == nil
    }

    /// Two readings, this one filling the holes in that one. Nothing here
    /// overwrites a word already said: the first answer is the answer, which
    /// is the rule the engine's own reading of AVFoundation follows too.
    func filling(_ other: TagReading) -> TagReading {
        var both = self
        if both.title == nil { both.title = other.title }
        if both.artist == nil { both.artist = other.artist }
        if both.album == nil { both.album = other.album }
        if both.picture == nil { both.picture = other.picture }
        return both
    }
}

/// The tags in a file's own bytes: an ID3v2 tag at the head of it, and the
/// metadata blocks of a FLAC. Read here and nowhere else, so that the engine
/// has one place to ask and one kind of answer to expect.
///
/// Synchronous, and deliberately so: it is called from the queue that reads a
/// track's tags (the engine's own detached task), and it reads the *head* of a
/// file rather than the file. A head is a few hundred kilobytes, the disk has
/// it in hand before the first frame of audio is decoded, and that is the
/// moment this is asked.
enum Tags {

    /// How far into a FLAC the blocks are followed. Metadata blocks sit ahead
    /// of the audio and a cover is the largest thing among them; past this
    /// there is either nothing or a file that is not what it says it is.
    private static let reach: UInt64 = 16 * 1024 * 1024
    /// The largest single block read at all. A twelve-megabyte cover is a
    /// picture nobody asked for, and reading one would cost more than the
    /// whole rest of the track's start.
    private static let largest = 12 * 1024 * 1024

    /// What the head of this file says. An empty reading is an answer too: it
    /// says the file keeps nothing here, and the folder is asked next.
    static func read(_ url: URL) -> TagReading {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return TagReading() }
        defer { try? handle.close() }
        var said = TagReading()
        var at: UInt64 = 0
        // The first ten bytes say which of the three kinds of file this is:
        // one with a tag in front of it, one whose own marker is first, and
        // one that keeps its words somewhere this file has no business
        // looking (an m4a, which AVFoundation has already read).
        if let head = read(handle, at: 0, count: 10), head.count == 10 {
            if Bytes(head).peek(3) == "ID3" {
                var cursor = Bytes(head)
                _ = cursor.word(3)
                // Two of the header's bytes as numbers: which version the tag
                // is, and what it says about itself. The version decides how a
                // frame says its own length, and nothing else here.
                let major = Int(cursor.byte() ?? 0)
                _ = cursor.byte()                   // the revision, which changes nothing here
                let flags = Int(cursor.byte() ?? 0)
                let size = cursor.u32(synchsafe: true) ?? 0
                // Ten bytes of header, then the tag's own length. A length
                // that is nonsense is a file that is not what it says it is,
                // and the rest of the reading is dropped rather than followed
                // into the audio.
                if size > 0, size <= largest {
                    let span = UInt64(10 + size)
                    if let tag = read(handle, at: 0, count: Int(span)),
                       let frames = ID3.read(tag, major: major, flags: flags) {
                        said = said.filling(frames)
                    }
                    at = span
                } else {
                    at = 10
                }
            } else if Bytes(head).peek(4) != "fLaC" {
                return said
            }
        }
        return said.filling(flac(handle, from: at))
    }

    // MARK: - a FLAC's own blocks

    /// The blocks of a FLAC, from wherever its own metadata begins: the
    /// marker, then block after block, each of them a kind and a length, until
    /// one says it was the last. Kind 4 is the Vorbis comment — the words —
    /// and kind 6 is the picture. Every other kind is stepped over, which is
    /// what a length is for.
    private static func flac(_ handle: FileHandle, from start: UInt64) -> TagReading {
        var said = TagReading()
        guard let marker = read(handle, at: start, count: 4),
              Bytes(marker).peek(4) == "fLaC" else { return said }
        var at = start + 4
        while at + 4 <= reach {
            guard let head = read(handle, at: at, count: 4) else { break }
            var cursor = Bytes(head)
            let first = cursor.byte() ?? 0
            let last = first & 0x80 != 0
            let kind = first & 0x7F
            guard let length = cursor.u24(), length > 0 else { break }
            at += 4
            switch kind {
            case 4 where length <= largest:
                if let block = read(handle, at: at, count: length) {
                    said = said.filling(comments(block))
                }
            case 6 where length <= largest:
                if let block = read(handle, at: at, count: length), let found = picture(block) {
                    // The front of the sleeve is the cover; a photograph of
                    // the band or the back of the sleeve is kept only while
                    // nothing better has turned up.
                    if said.picture == nil || found.front { said.picture = found.data }
                }
            default:
                break
            }
            at += UInt64(length)
            // Kind 127 is the format's own "there is nothing more worth
            // reading here", and the last block says the same thing politely.
            if last || kind == 127 { break }
        }
        return said
    }

    /// A Vorbis comment block: who wrote it, then this many `NAME=value`
    /// pairs, each of them a length and then UTF-8. The names are the ones the
    /// format's own documentation proposes, and the picture — when a file
    /// keeps it in a comment rather than in a block of its own — is that same
    /// picture block, base64'd, under `METADATA_BLOCK_PICTURE`.
    private static func comments(_ block: Data) -> TagReading {
        var said = TagReading()
        var cursor = Bytes(block)
        // Who wrote the tag, which is of no interest to anybody here but has
        // to be walked over to get to the words.
        guard cursor.string() != nil else { return said }
        guard let count = cursor.u32(), count > 0, count < 1_000 else { return said }
        for _ in 0..<count {
            guard let pair = cursor.string(), let equals = pair.firstIndex(of: "=") else { continue }
            let name = String(pair[pair.startIndex..<equals]).uppercased()
            let value = String(pair[pair.index(after: equals)...])
            switch name {
            case "TITLE":
                if said.title == nil { said.title = word(value) }
            case "ARTIST":
                if said.artist == nil { said.artist = word(value) }
            case "ALBUM":
                if said.album == nil { said.album = word(value) }
            case "METADATA_BLOCK_PICTURE":
                // Whitespace is allowed in the encoding, and a comment that
                // will not decode is a comment that said nothing.
                if said.picture == nil,
                   let held = Data(base64Encoded: value, options: .ignoreUnknownCharacters),
                   let found = picture(held) {
                    said.picture = found.data
                }
            default:
                continue
            }
        }
        return said
    }

    /// One PICTURE block: what kind of picture it is, what it is encoded as,
    /// what it is called, how big it is — and then the picture. Everything
    /// before the bytes that matter is a length or a number, so the walk to
    /// them is arithmetic and nothing else.
    private static func picture(_ block: Data) -> (front: Bool, data: Data)? {
        var cursor = Bytes(block)
        guard let kind = cursor.u32() else { return nil }
        guard cursor.string() != nil else { return nil }      // what the picture is encoded as
        guard cursor.string() != nil else { return nil }      // what it is called
        guard cursor.take(4) != nil else { return nil }       // how wide and how tall
        guard cursor.take(6) != nil else { return nil }       // how deep, how many colours
        guard let length = cursor.u32(), length > 0 else { return nil }
        guard let held = cursor.take(length) else { return nil }
        return (kind == 3, Data(held))                        // 3 is the front of the sleeve
    }

    // MARK: - the small readings

    /// A word worth saying: what is there with the space taken off both ends,
    /// and nothing at all if that leaves nothing.
    private static func word(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// That many bytes from that place in that file, or nothing at all: a read
    /// past the end, a file that went away, a disk that is not plugged in any
    /// more — all of them are the same answer here, and it is "nothing".
    private static func read(_ handle: FileHandle, at place: UInt64, count: Int) -> Data? {
        guard count > 0 else { return nil }
        do {
            try handle.seek(toOffset: place)
            // `read(upToCount:)` and not the older `readData(ofLength:)`: this
            // one throws, and returns nothing at all rather than an empty
            // reading when the file ends first.
            return try handle.read(upToCount: count)
        } catch {
            return nil
        }
    }
}

/// An ID3v2 tag: the frames of it that this player wants, read out of the
/// bytes of the whole tag.
///
/// Versions 2.3 and 2.4, which is what a file of the last twenty-five years
/// carries. The two differ in one place that matters here — how a frame says
/// its own length, a plain number in 2.3 and a synchsafe one in 2.4 — and both
/// are handled. Version 2.2, whose frames have three-letter names and
/// three-byte lengths, is not: it predates every file this player is likely to
/// be handed, and a tag that cannot be read leaves the window calling the
/// track by its filename, exactly as a file with no tags at all does.
enum ID3 {

    static func read(_ tag: Data, major: Int, flags: Int) -> TagReading? {
        var cursor = Bytes(tag)
        guard cursor.word(3) == "ID3" else { return nil }
        // Past the ten bytes of header, which have been read already.
        cursor.at = 10
        // An extended header is a length and then that many bytes of nothing
        // this player wants. The two versions count it differently: 2.4's
        // length includes the four bytes it is written in, 2.3's does not.
        if flags & 0x40 != 0 {
            guard let span = cursor.u32(synchsafe: major >= 4) else { return nil }
            cursor.at += major >= 4 ? max(0, span - 4) : span
        }
        var said = TagReading()
        // Frame after frame until the padding begins: a frame whose name is
        // not four capitals and digits is the tag's own way of saying that the
        // rest of it is zeroes.
        while cursor.left >= 10 {
            guard let name = cursor.word(4), name.count == 4, isFrame(name) else { break }
            guard let length = cursor.u32(synchsafe: major >= 4) else { break }
            guard cursor.take(2)?.count == 2 else { break }      // the frame's own flags
            guard let body = cursor.take(length) else { break }
            switch name {
            case "TIT2": said.title = said.title ?? text(body)
            case "TPE1": said.artist = said.artist ?? text(body)
            case "TALB": said.album = said.album ?? text(body)
            case "APIC":
                if said.picture == nil { said.picture = attached(body) }
            default: continue
            }
        }
        return said
    }

    /// Whether that is a frame's name at all: four capital letters or digits,
    /// which is what the format allows and what tells a walk through the tag
    /// that it has come to the padding.
    private static func isFrame(_ name: String) -> Bool {
        name.unicodeScalars.allSatisfy {
            ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9")
        }
    }

    /// A text frame: one byte saying how the rest of it is written, then the
    /// words. The four encodings are the format's own, and all four are
    /// Foundation's too.
    private static func text(_ body: [UInt8]) -> String? {
        guard let coding = body.first else { return nil }
        guard let said = string(Data(body.dropFirst()), coding: coding) else { return nil }
        let trimmed = said
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// An attached picture: how the words in the frame are written, what the
    /// picture is encoded as, what kind of picture it is, what it is called —
    /// and then the picture. The two names are terminated rather than counted,
    /// and the terminator of a UTF-16 one is two zero bytes rather than one,
    /// which is the only place this walk has to know how the text is written.
    private static func attached(_ body: [UInt8]) -> Data? {
        var cursor = Bytes(body)
        guard let coding = cursor.byte() else { return nil }
        // What the picture is encoded as: ASCII, ended by one zero byte.
        while let one = cursor.byte(), one != 0 {}
        _ = cursor.byte()                                          // what kind of picture it is
        if coding == 1 || coding == 2 {
            while cursor.left >= 2, let pair = cursor.take(2), pair != [0, 0] {}
        } else {
            while let one = cursor.byte(), one != 0 {}
        }
        guard cursor.left > 0, let held = cursor.take(cursor.left) else { return nil }
        return Data(held)
    }

    private static func string(_ data: Data, coding: UInt8) -> String? {
        switch coding {
        case 0: return String(data: data, encoding: .isoLatin1)
        case 1: return String(data: data, encoding: .utf16)
        case 2: return String(data: data, encoding: .utf16BigEndian)
        default: return String(data: data, encoding: .utf8)
        }
    }
}

/// A walk through bytes, with a place in them.
///
/// Everything the two readers above do is "take this many, say what they
/// meant", and doing it against a `Data` directly is a trap: a slice of a
/// `Data` keeps the indices of the data it came out of, so the tenth byte of a
/// slice is not at index ten. An array of bytes has no second meaning to it,
/// and a cursor over one has nothing to get wrong.
struct Bytes {
    let bytes: [UInt8]
    var at = 0

    init(_ data: Data) { bytes = [UInt8](data) }

    /// The same cursor over bytes that are already an array, which is what the
    /// frames of an ID3 tag are once they have been taken out of it.
    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var left: Int { max(0, bytes.count - at) }

    mutating func take(_ count: Int) -> [UInt8]? {
        guard count >= 0, left >= count else { return nil }
        guard count > 0 else { return [] }
        let held = Array(bytes[at..<at + count])
        at += count
        return held
    }

    mutating func byte() -> UInt8? {
        take(1)?.first
    }

    /// That many bytes as letters, for the markers and the frame names.
    mutating func word(_ count: Int) -> String? {
        guard let held = take(count) else { return nil }
        return String(bytes: held, encoding: .ascii)
    }

    /// The same letters, without moving: for asking a file what it is before
    /// deciding whether to read it. Asking is not a mutation, and a question
    /// put to a reading that is only being looked at has no business changing
    /// where that reading is.
    func peek(_ count: Int) -> String? {
        guard count >= 0, left >= count, count > 0 else { return nil }
        return String(bytes: bytes[at..<at + count], encoding: .ascii)
    }

    /// A number in the bytes that follow, big-endian as both formats ask.
    mutating func u24() -> Int? {
        guard let held = take(3) else { return nil }
        return Int(held[0]) << 16 | Int(held[1]) << 8 | Int(held[2])
    }

    mutating func u32(synchsafe: Bool = false) -> Int? {
        guard let held = take(4) else { return nil }
        guard synchsafe else {
            return (Int(held[0]) << 24) | (Int(held[1]) << 16) | (Int(held[2]) << 8) | Int(held[3])
        }
        // Seven bits apiece: a synchsafe number is one with the top bit of
        // every byte left empty, so that it can never be mistaken for the
        // start of an mp3 frame.
        return (Int(held[0] & 0x7F) << 21)
            | (Int(held[1] & 0x7F) << 14)
            | (Int(held[2] & 0x7F) << 7)
            | Int(held[3] & 0x7F)
    }

    /// A string with its own length in front of it, which is how a Vorbis
    /// comment keeps each of its pairs — and how a PICTURE block keeps its two
    /// names. A length of nought is a string of nothing rather than a failure:
    /// an encoder that wrote no vendor name and no mime type still wrote a
    /// picture, and a reader that gave up on the first empty string would be a
    /// reader that gave up on the file.
    mutating func string() -> String? {
        guard let length = u32(), length >= 0, left >= length else { return nil }
        guard let held = take(length) else { return nil }
        return String(bytes: held, encoding: .utf8)
    }
}

/// The picture lying beside the music.
///
/// An album kept as files with no covers in them is usually kept with one
/// picture in the folder instead, and the names that picture goes by are a
/// short list everybody agrees on. The folder is read once and the reading is
/// kept, and the names are asked for in an order: the track's own name first,
/// because a folder of singles with a picture apiece is a thing that exists,
/// and then `cover`, `folder`, `front`, `album`, `art` and `artwork` — because
/// that is the order in which a picture is the album's rather than somebody's
/// idea of one.
///
/// Nothing here is fetched and nothing here is guessed: a sidecar is a file on
/// this Mac, in the folder the track was opened from, or it is not there.
enum Sidecar {

    /// The names a folder's cover goes by, in the order they are asked for.
    private static let names = ["cover", "folder", "front", "album", "art", "artwork"]
    /// The kinds of picture that are read. ImageIO decodes every one of them,
    /// and every one of them is what a cover gets saved as.
    private static let kinds = ["jpg", "jpeg", "png", "heic", "tif", "tiff", "webp"]

    /// The picture beside this track, if there is one.
    static func cover(for track: URL) -> URL? {
        let folder = track.deletingLastPathComponent()
        let inside = Folders.shared.contents(of: folder)
        guard !inside.isEmpty else { return nil }
        // By lowercased name, once: a folder is asked about in the order the
        // names are wanted, not in the order the disk handed them back.
        var byName: [String: URL] = [:]
        for url in inside { byName[url.lastPathComponent.lowercased()] = url }
        let stem = track.deletingPathExtension().lastPathComponent.lowercased()
        for kind in kinds {
            if let own = byName[stem + "." + kind] { return own }
        }
        for name in names {
            for kind in kinds {
                if let found = byName[name + "." + kind] { return found }
            }
        }
        return nil
    }

    /// A listing kept for the folder rather than asked for again on every
    /// track of it: an album is twelve files and one picture, and reading the
    /// folder twelve times to find the same picture is twelve readings too
    /// many. Kept by the folder's own modification date, so a folder changed
    /// since is read again — and kept small, because a listener with a library
    /// on a disk walks through folders all afternoon.
    private final class Folders: @unchecked Sendable {
        static let shared = Folders()

        private let lock = NSLock()
        private var held: [String: (stamp: Date?, inside: [URL])] = [:]
        /// How many folders are remembered at once. A listing is a few hundred
        /// bytes; this is a ceiling on that, not a tuning knob.
        private let room = 24

        func contents(of folder: URL) -> [URL] {
            let key = folder.path
            let stamp = Self.stamp(of: folder)
            lock.lock()
            if let known = held[key], known.stamp == stamp {
                let inside = known.inside
                lock.unlock()
                return inside
            }
            lock.unlock()
            // Read outside the lock: a disk is a disk, and a listing that
            // holds every other reading up while it waits is a listing taken
            // too seriously.
            let inside = (try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            let pictures = inside.filter {
                Sidecar.kinds.contains($0.pathExtension.lowercased())
                    && (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == false
            }
            lock.lock()
            if held.count >= room { held.removeAll() }
            held[key] = (stamp, pictures)
            lock.unlock()
            return pictures
        }

        /// When the folder was last changed, which is what makes a remembered
        /// listing worth keeping: a picture dropped into a folder since is a
        /// picture this finds.
        private static func stamp(of folder: URL) -> Date? {
            (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
    }
}

/// The pictures already decoded, kept for as long as they are being looked at
/// again — which is the length of a queue, because a listener walks back
/// through what they opened.
///
/// A cover is decoded to a thumbnail of at most the engine's own metric before
/// it is kept, so what is held here is small, and the ceiling on how many are
/// held is what keeps an afternoon of an album's tracks from becoming an
/// afternoon of memory. The blurred wash a window wears is *not* kept: it is
/// made again for each track from the picture that is, and a second picture
/// apiece for a whole queue is exactly what this shelf exists to avoid.
enum ArtCache {

    private static let shelf = Shelf()

    /// The picture of that file, decoded once and asked for again. What makes
    /// the key is the file, the moment it was last written and where the
    /// picture came from, so a cover replaced in the file since is a different
    /// picture and is read again — a cache that outlives the file it came out
    /// of is a lie.
    static func picture(
        of file: URL,
        embedded: Bool,
        side: CGFloat,
        make: () -> CGImage?
    ) -> CGImage? {
        let written = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate?.timeIntervalSince1970 ?? 0
        let key = "\(embedded ? "in" : "by")|\(Int(side))|\(file.path)|\(Int(written))"
        if let held = shelf.take(key) { return held }
        guard let made = make() else { return nil }
        shelf.put(key, made)
        return made
    }

    /// A ceiling of pictures, the oldest out first.
    private final class Shelf: @unchecked Sendable {
        private let lock = NSLock()
        private var order: [String] = []
        private var held: [String: CGImage] = [:]
        /// Four covers at the engine's own thumbnail size: enough that walking
        /// back through an album reads the disk once, small enough that the
        /// player stays the size it is.
        private let room = 4

        func take(_ key: String) -> CGImage? {
            lock.lock()
            defer { lock.unlock() }
            return held[key]
        }

        func put(_ key: String, _ image: CGImage) {
            lock.lock()
            defer { lock.unlock() }
            if held[key] == nil {
                held[key] = image
                order.append(key)
            }
            while order.count > room {
                held.removeValue(forKey: order.removeFirst())
            }
        }
    }
}
