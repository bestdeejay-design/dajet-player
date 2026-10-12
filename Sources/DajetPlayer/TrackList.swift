import AVFoundation
import Foundation

// The names the folder's list shows, one for every track in the queue. The
// engine reads the tags of the track that is playing and nothing else, and
// the list wants the title of every track in the folder — so the window reads
// the titles itself, one file at a time, from the files that were opened and
// from nowhere else. Local files only: nothing here is a network request.
//
// A track whose file says no title is called by its filename, the way the
// line at the foot of the window has always called it.

@MainActor
final class TrackNames: ObservableObject {
    /// The name of each track read so far, by the file it came from. A track
    /// not in here yet is shown by its filename until its reading comes back.
    @Published private(set) var titles: [URL: String] = [:]

    /// The reading on its way, cancelled by the next queue that arrives.
    private var reading: Task<Void, Never>?

    /// The name a track is shown by: its title when the reading has found one,
    /// and its filename while it has not — or when it never will.
    func name(of url: URL) -> String {
        titles[url] ?? url.lastPathComponent
    }

    /// A new queue has been opened: the titles of the tracks in it are read,
    /// the ones already known are kept, and the titles of the tracks that have
    /// gone out of the queue are let go of.
    func read(_ urls: [URL]) {
        reading?.cancel()
        let wanted = Set(urls)
        titles = titles.filter { wanted.contains($0.key) }
        let missing = urls.filter { titles[$0] == nil }
        guard !missing.isEmpty else {
            reading = nil
            return
        }
        reading = Task { [weak self] in
            for url in missing {
                if Task.isCancelled { return }
                let title = await Self.title(of: url)
                // Whatever the tags say, the track is now known: a file with
                // no title is called by its filename from here on, and is not
                // read again for it.
                guard let self, !Task.isCancelled else { return }
                self.titles[url] = title ?? url.lastPathComponent
            }
        }
    }

    /// The title out of one file's own tags, trimmed; nil if it has none.
    private nonisolated static func title(of url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata),
              let item = items.first(where: { $0.commonKey == AVMetadataKey.commonKeyTitle }),
              let string = try? await item.load(.stringValue) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
