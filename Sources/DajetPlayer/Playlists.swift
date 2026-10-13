import AppKit
import Foundation

// Playlists: folders of music, kept in a small file of their own.
//
// The model is the browser's bookmarks (dajet-browser/Sources/Dajet/Bookmarks.swift):
// the app's own list, in the app's own file, rather than anything the system
// owns. A system menu can't be dragged into, can't be asked a second thing by
// right-clicking it, and can't say what a playlist's folder is doing — and a
// folder you keep music in wants all three.
//
// They live in `~/Library/Application Support/Dajet Player/playlists.json`:
// the folder the README has promised since wave 2, the one place this app
// keeps anything, and the only thing it writes anywhere.
//
// A playlist is a *folder*, not a track and not a queue: adding one is a
// pointer at where the music is, and the music stays where it was. That is
// also why nothing here is ever a network address: a folder on this Mac is the
// only thing a playlist can be.

/// One playlist: a folder of music, by the name it went in under and by where
/// it is.
struct Playlist: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var path: String

    var url: URL { URL(fileURLWithPath: path) }

    /// The path of a folder with nothing on the end of it. The same folder
    /// arrives with a slash on the end of its URL from one place and without
    /// one from another — a panel gives one, a drop from the Finder gives
    /// another — and the two have to be able to come out the same, or the menu
    /// cannot tell the folder it is showing from the folder being played.
    static func plain(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// Whether this playlist *is* that folder.
    func isFolder(_ url: URL) -> Bool {
        Playlist.plain(url) == Playlist.plain(self.url)
    }

    /// Whether the folder is still where it was. A playlist whose folder has
    /// gone — a disk that is not plugged in, a folder that was moved — stays
    /// in the menu, greyed, until it is removed by hand: it is the listener's
    /// list, and nothing but a hand deletes from it.
    var there: Bool {
        var folder: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &folder)
        return exists && folder.boolValue
    }
}

/// The playlists, and the one file they live in.
@MainActor
final class Playlists: ObservableObject {
    /// In the order they were added: the menu shows them in the order a hand
    /// put them there, and nothing sorts them behind the listener's back.
    @Published private(set) var list: [Playlist] = []

    /// The writes, in the order they were asked for — one serial queue, so the
    /// last write to land is the state that was set last. A few hundred bytes
    /// apiece and one write per click, off the main thread because a disk is a
    /// disk.
    private let disk = DispatchQueue(label: "ru.dajet.player.playlists", qos: .utility)

    init() { load() }

    var isEmpty: Bool { list.isEmpty }

    /// A folder joins the menu. One that is already there is not added twice:
    /// the menu is a list of folders and not a list of gestures.
    @discardableResult
    func add(_ url: URL) -> Playlist? {
        let path = Playlist.plain(url)
        guard !list.contains(where: { $0.path == path }) else { return nil }
        let playlist = Playlist(name: url.lastPathComponent, path: path)
        list.append(playlist)
        save()
        return playlist
    }

    /// A playlist is removed, and the folder it points at is not touched: the
    /// menu was the only thing that knew about it.
    func remove(_ id: Playlist.ID) {
        guard let place = list.firstIndex(where: { $0.id == id }) else { return }
        list.remove(at: place)
        save()
    }

    // MARK: - the file

    /// The one file this player owns.
    static var file: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return support
            .appendingPathComponent("Dajet Player", isDirectory: true)
            .appendingPathComponent("playlists.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.file) else { return }
        list = (try? JSONDecoder().decode([Playlist].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(list) else { return }
        let file = Self.file
        disk.async {
            // The folder is made when it is first needed rather than at
            // launch: a player nobody has added a folder to writes nothing
            // anywhere at all.
            try? FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: file, options: .atomic)
        }
    }
}

/// The one way in by panel: a folder of music, chosen the Mac's way — the menu
/// bar's ⌘O and the button in the window are the same two lines, and both do
/// exactly what dropping the folder on the window does. It joins the menu, and
/// it plays: opening a folder plays it, which is the contract the playback
/// core was built on (P-03) and is not this wave's to change.
enum Chooser {
    @MainActor
    static func folder(into playlists: Playlists, for engine: PlayerEngine) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Where music lives on an ordinary Mac, to save the walk there.
        panel.directoryURL = FileManager.default
            .urls(for: .musicDirectory, in: .userDomainMask).first
        panel.prompt = "Play"
        panel.message = "A folder of music: \(PlayerEngine.kinds). It joins the side menu."
        guard panel.runModal() == .OK, let folder = panel.urls.first else { return }
        playlists.add(folder)
        engine.open([folder])
    }
}
