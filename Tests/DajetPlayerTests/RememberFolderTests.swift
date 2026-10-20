import AppKit
import XCTest
@testable import DajetPlayer

@MainActor
final class RememberFolderTests: XCTestCase {

    // MARK: - fixtures

    private func defaults() -> (UserDefaults, String) {
        let name = "ru.dajet.player.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    private func makeSandbox() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent("dajet-player-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeAlbum(in root: URL, named name: String, tracks: [String]) throws -> URL {
        let folder = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let wav = Self.minimalWAV()
        for track in tracks {
            try wav.write(to: folder.appendingPathComponent(track))
        }
        return folder
    }

    /// A valid 16-bit mono 8 kHz PCM WAV file so AVFoundation treats test
    /// tracks as genuine audio.
    private static func minimalWAV() -> Data {
        let sampleRate: UInt32 = 8_000
        let sampleCount: UInt32 = 800
        let dataSize = sampleCount * 2
        let riffSize = 36 + dataSize
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian32(riffSize))
        data.append(contentsOf: "WAVEfmt ".utf8)
        data.append(littleEndian32(16))
        data.append(littleEndian16(1))
        data.append(littleEndian16(1))
        data.append(littleEndian32(sampleRate))
        data.append(littleEndian32(sampleRate * 2))
        data.append(littleEndian16(2))
        data.append(littleEndian16(16))
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian32(dataSize))
        data.append(Data(count: Int(dataSize)))
        return data
    }

    private static func littleEndian16(_ value: UInt16) -> Data {
        var le = value.littleEndian
        return withUnsafeBytes(of: &le) { Data($0) }
    }

    private static func littleEndian32(_ value: UInt32) -> Data {
        var le = value.littleEndian
        return withUnsafeBytes(of: &le) { Data($0) }
    }

    // MARK: - tests

    func testStartsEmptyWhenNoBookmarkExists() {
        _ = NSApplication.shared
        let (store, suite) = defaults()
        defer { store.removePersistentDomain(forName: suite) }

        let engine = PlayerEngine(defaults: store)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.track)
        XCTAssertNil(engine.source)
        XCTAssertEqual(engine.count, 0)
        XCTAssertNil(engine.note)
        XCTAssertNil(engine.scopedFolder)
        XCTAssertNil(store.object(forKey: PlayerEngine.Remembered.folder))
    }

    func testRemembersFolderAsBookmarkAndRestoresOnNextLaunch() throws {
        _ = NSApplication.shared
        let (store, suite) = defaults()
        defer { store.removePersistentDomain(forName: suite) }
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let album = try makeAlbum(in: root, named: "Album", tracks: ["01-first.wav", "02-second.wav"])

        let firstRun = PlayerEngine(defaults: store)
        firstRun.open([album])

        let savedBookmark = store.data(forKey: PlayerEngine.Remembered.folder)
        XCTAssertNotNil(savedBookmark, "Opening a folder stores bookmark Data in UserDefaults")
        XCTAssertNil(store.string(forKey: PlayerEngine.Remembered.folder),
                     "Stored value is bookmark Data, not a raw path string")
        XCTAssertEqual(firstRun.scopedFolder.map(Playlist.plain), Playlist.plain(album))
        XCTAssertEqual(firstRun.count, 2)

        firstRun.stopAccessingFolder()
        XCTAssertNil(firstRun.scopedFolder, "Closing releases security-scoped access")

        let secondRun = PlayerEngine(defaults: store)
        defer { secondRun.stopAccessingFolder() }
        XCTAssertEqual(secondRun.source.map(Playlist.plain), Playlist.plain(album))
        XCTAssertEqual(secondRun.scopedFolder.map(Playlist.plain), Playlist.plain(album))
        XCTAssertEqual(secondRun.count, 2)
        XCTAssertEqual(secondRun.number, 1)
        XCTAssertEqual(secondRun.track?.lastPathComponent, "01-first.wav")
        XCTAssertNil(secondRun.note)

        secondRun.toggle()
        XCTAssertEqual(secondRun.state, .playing, "Restored library can be played immediately")
        secondRun.toggle()
    }

    func testSwitchingFolderReplacesBookmark() throws {
        _ = NSApplication.shared
        let (store, suite) = defaults()
        defer { store.removePersistentDomain(forName: suite) }
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let firstAlbum = try makeAlbum(in: root, named: "First", tracks: ["01-a.wav"])
        let secondAlbum = try makeAlbum(in: root, named: "Second", tracks: ["01-b.wav", "02-b.wav", "03-b.wav"])

        let engine = PlayerEngine(defaults: store)
        engine.open([firstAlbum])
        let firstBookmark = store.data(forKey: PlayerEngine.Remembered.folder)
        XCTAssertNotNil(firstBookmark)

        engine.open([secondAlbum])
        let secondBookmark = store.data(forKey: PlayerEngine.Remembered.folder)
        XCTAssertNotNil(secondBookmark)
        XCTAssertNotEqual(firstBookmark, secondBookmark, "New folder replaces previous bookmark")
        XCTAssertEqual(engine.scopedFolder.map(Playlist.plain), Playlist.plain(secondAlbum))
        engine.stopAccessingFolder()

        let restored = PlayerEngine(defaults: store)
        defer { restored.stopAccessingFolder() }
        XCTAssertEqual(restored.source.map(Playlist.plain), Playlist.plain(secondAlbum))
        XCTAssertEqual(restored.count, 3)
        XCTAssertEqual(restored.track?.lastPathComponent, "01-b.wav")
    }

    func testDeletedFolderClearsBookmarkAndShowsCalmNote() throws {
        _ = NSApplication.shared
        let (store, suite) = defaults()
        defer { store.removePersistentDomain(forName: suite) }
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let album = try makeAlbum(in: root, named: "Vanishing", tracks: ["01-song.wav"])

        let firstRun = PlayerEngine(defaults: store)
        firstRun.open([album])
        firstRun.stopAccessingFolder()
        XCTAssertNotNil(store.data(forKey: PlayerEngine.Remembered.folder))

        try FileManager.default.removeItem(at: album)

        let secondRun = PlayerEngine(defaults: store)
        XCTAssertNil(store.object(forKey: PlayerEngine.Remembered.folder),
                     "Missing folder removes its stale bookmark")
        XCTAssertEqual(secondRun.state, .idle)
        XCTAssertNil(secondRun.track)
        XCTAssertNil(secondRun.source)
        XCTAssertEqual(secondRun.count, 0)
        XCTAssertNil(secondRun.scopedFolder)
        XCTAssertEqual(secondRun.note, PlayerEngine.folderUnavailable)
    }

    func testRenamedFolderClearsBookmarkAndShowsCalmNote() throws {
        _ = NSApplication.shared
        let (store, suite) = defaults()
        defer { store.removePersistentDomain(forName: suite) }
        let root = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let album = try makeAlbum(in: root, named: "Before", tracks: ["01-song.wav"])
        let renamed = root.appendingPathComponent("After", isDirectory: true)

        let firstRun = PlayerEngine(defaults: store)
        firstRun.open([album])
        firstRun.stopAccessingFolder()

        try FileManager.default.moveItem(at: album, to: renamed)

        let secondRun = PlayerEngine(defaults: store)
        XCTAssertNil(store.object(forKey: PlayerEngine.Remembered.folder),
                     "Renamed folder clears old bookmark instead of failing silently")
        XCTAssertEqual(secondRun.state, .idle)
        XCTAssertNil(secondRun.track)
        XCTAssertEqual(secondRun.count, 0)
        XCTAssertNil(secondRun.scopedFolder)
        XCTAssertEqual(secondRun.note, PlayerEngine.folderUnavailable)

        secondRun.open([renamed])
        defer { secondRun.stopAccessingFolder() }
        XCTAssertNil(secondRun.note, "Opening another folder clears the unavailable note")
        XCTAssertEqual(secondRun.source.map(Playlist.plain), Playlist.plain(renamed))
        XCTAssertEqual(secondRun.count, 1)
        XCTAssertNotNil(store.data(forKey: PlayerEngine.Remembered.folder))
    }
}
