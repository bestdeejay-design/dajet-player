import AppKit
import SwiftUI

// The side menu: the browser's own column, with playlists in it.
//
// The mechanics are the browser's (dajet-browser/Sources/Dajet/Side.swift and
// Fold.swift): the column rests at 232 points and can be pulled between 176 and
// 440 by its own edge, it comes and goes on one spring (Motion.glide), and it
// slides out over the player rather than shoving it. What is new here is what
// is *inside* it — playlists.
//
// A playlist is a folder of music: the ones that were added (⌘O, or dropped on
// the window) and not yet removed. They are kept in a small file of their own
// (Playlists.swift) and they are the player's list, not the system's: a system
// menu can't be dragged into and can't be asked a second thing by
// right-clicking it, and a folder you keep music in wants both.
//
// The column has no band of its own, no toggle in it and no button at its foot
// (P-10). The toggle is the window's toolbar's, at the leading end beside the
// traffic lights, and it is there whether the column is out or away — which is
// the whole of what a toggle has to be, and is why the column does not need a
// second one. What is left of the band a hand drew there was a guess at where
// the traffic lights are and a strip that took a drag on the window's behalf;
// the toolbar is given both by the platform. The foot's "Add Folder…" was the
// third way of doing a thing the toolbar's button, the tray's menu and ⌘O
// already do, in the one window that shows all of them at once — and an element
// that duplicates the toolbar is an element the owner asked to have out.
//
// A click on a playlist shows its tracks and plays it — opening a folder plays
// it, which is the contract the playback core was built on and is not this
// wave's to change. A click on a track plays that track, and the track that is
// being heard is marked, as the folder it came from is. The arrow beside a
// playlist opens and closes its list and touches nothing that is playing,
// which is how a listener looks through a folder without interrupting one.

struct SideMenu: View {
    @ObservedObject var engine: PlayerEngine
    @ObservedObject var playlists: Playlists
    /// The width the column has in the window, and the two it lives between.
    @Binding var span: Double
    /// A number that goes up whenever an open list is out of date — the menu
    /// has just come out, or a folder has just been added — so that the tracks
    /// shown are the folder's tracks now and not the ones from an hour ago.
    var refresh: Int
    /// The playlist whose tracks are shown. One at a time, which is what a
    /// column this narrow can hold honestly.
    @State private var showing: Playlist.ID?
    /// The width the column had when its edge was picked up.
    @State private var grabbed: Double?
    @State private var onEdge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if playlists.isEmpty {
                empty
            } else {
                Head()
                list
            }
            Spacer(minLength: 0)
        }
        // The width is the window's decision and not this column's: the player
        // clamps it to the room there is, so that a window narrower than the
        // column is a window with a drawer over the player rather than a column
        // hanging off the edge of the glass (P-10). What the column owns is the
        // range it is pulled between, and the edge that pulls it.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Metrics.gap)
        // What the column is made of: the window's own surface and nothing
        // else. Deliberately *not* a second pane of glass — a material laid
        // under a material is the one thing the platform's own guidance says
        // never to do, and it is right: two translucent layers read as fog,
        // and the second one only blurs the first one's blur. So the column is
        // one wash over whatever the window already is (Palette.side: a step
        // deeper than the glass in the light theme, a step lighter than the
        // matte in the dark), and the hairline and the shadow at its edge are
        // what say it is a column rather than a shade.
        .background(Palette.side)
        // The shadow it casts on what it is over, which is what says it is
        // *over* something rather than beside it.
        .shadow(color: .black.opacity(0.18), radius: 14, x: 4)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.hairline).frame(width: 1)
        }
        .overlay(alignment: .trailing) { edge }
        // A folder becoming what is playing — dropped, chosen from the panel,
        // or clicked in this very menu — is the one that should be open.
        .onChange(of: engine.source) { _, source in
            guard let source,
                  let match = playlists.list.first(where: { $0.isFolder(source) }) else { return }
            showing = match.id
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - what is in it

    private var list: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(playlists.list) { playlist in
                    PlaylistRow(
                        playlist: playlist,
                        engine: engine,
                        open: showing == playlist.id,
                        refresh: refresh,
                        toggle: { toggle(playlist.id) },
                        play: { open(playlist) },
                        remove: { playlists.remove(playlist.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        }
        .frame(maxHeight: .infinity)
    }

    /// Nothing in the menu at all, which is where a fresh copy of the player
    /// starts: no folder is built in, and nothing plays until one is added
    /// (P-06R). The column says so rather than sitting blank and looking
    /// broken — and it points at the two ways in, which are the toolbar's and
    /// the window's, and not a third button of its own (P-10).
    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No playlists yet.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
            Text("Add a folder above, or drop one on the window: it stays here, and it plays.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The column's edge: pull it to size the column, double-click it to put
    /// it back to where it rests. The hairline darkens under the pointer, so
    /// the edge says it can be taken before it is — the browser's edge, at the
    /// same width and with the same cursor.
    private var edge: some View {
        Rectangle()
            .fill(Palette.ink.opacity(onEdge || grabbed != nil ? 0.18 : 0))
            .frame(width: onEdge || grabbed != nil ? 2 : 1)
            .frame(width: Metrics.pull)
            .contentShape(Rectangle())
            .onHover { over in
                onEdge = over
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { hand in
                        if grabbed == nil { grabbed = span }
                        let wanted = (grabbed ?? span) + Double(hand.translation.width)
                        span = min(Double(Metrics.sideMax), max(Double(Metrics.sideMin), wanted))
                    }
                    .onEnded { _ in grabbed = nil }
            )
            .onTapGesture(count: 2) {
                withAnimation(Motion.settle) { span = Double(Metrics.side) }
            }
            .animation(Motion.quick, value: onEdge)
    }

    // MARK: - what a click does

    /// The arrow: the playlist's list, open or closed. Nothing is played and
    /// nothing stops playing.
    private func toggle(_ id: Playlist.ID) {
        withAnimation(Motion.settle) {
            showing = showing == id ? nil : id
        }
    }

    /// The row itself: the playlist is shown, and — unless this is the folder
    /// that is already playing — opened, which starts it from its first track.
    private func open(_ playlist: Playlist) {
        guard playlist.there else { return }
        withAnimation(Motion.settle) { showing = playlist.id }
        // Already this folder's queue, with something in it: the click is a
        // hand asking to see where the player is, not asking it to start over.
        let already = engine.source.map { playlist.isFolder($0) } ?? false
        guard !already || engine.track == nil else { return }
        engine.open([playlist.url])
    }
}

/// The word over the list: what the column holds, said the way a Mac says a
/// group's name — small, quiet, and out of the way of the rows themselves.
private struct Head: View {
    var body: some View {
        Text("PLAYLISTS")
            .font(.system(size: 10, weight: .medium))
            .tracking(0.7)
            .foregroundStyle(Palette.faint)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - one playlist, and the tracks in it

/// One playlist: the folder's name, the arrow that opens its list, and — open
/// — the tracks themselves. The arrow is a button of its own so that looking
/// through a folder never interferes with what is being heard.
private struct PlaylistRow: View {
    let playlist: Playlist
    let engine: PlayerEngine
    let open: Bool
    let refresh: Int
    let toggle: () -> Void
    let play: () -> Void
    let remove: () -> Void

    @State private var tracks: [URL] = []
    /// Whether the folder is still where it was, read when the list is read
    /// and not on every redraw: a row that asks the disk a question each time
    /// the pointer moves across it is a row that makes a window feel like
    /// work.
    @State private var there = true
    @State private var hovering = false

    /// Whether this is the folder the player is walking. The menu marks it:
    /// the column has to say where the music is coming from, or a list of
    /// folders of music says nothing at all. Compared by path rather than by
    /// URL, so that a folder chosen from the panel and the same folder dropped
    /// from the Finder are the same folder here.
    private var current: Bool {
        guard let source = engine.source else { return false }
        return playlist.isFolder(source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            if open { inside }
        }
        .onAppear { read() }
        .onChange(of: refresh) { _, _ in read() }
        .onChange(of: open) { _, now in if now { read() } }
    }

    private var row: some View {
        HStack(spacing: 2) {
            Button(action: toggle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.faint)
                    .rotationEffect(.degrees(open ? 90 : 0))
                    .frame(width: 18, height: Metrics.row)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(open ? "Close this folder's tracks" : "Show this folder's tracks")
            .accessibilityLabel(open ? "Close \(playlist.name)" : "Open \(playlist.name)")

            Button(action: play) {
                HStack(spacing: 6) {
                    Text(playlist.name)
                        .font(.system(size: 13, weight: current ? .semibold : .regular))
                        .foregroundStyle(nameColour)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    if current {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .padding(.trailing, 8)
                .frame(height: Metrics.row)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!there)
            .help(there ? playlist.path : "This folder is not there any more")
            .accessibilityLabel(playlist.name)
            .accessibilityValue(current ? "Playing" : "")
        }
        .padding(.leading, 4)
        .background(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .fill(hovering ? Palette.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Play") { play() }
                .disabled(!there)
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([playlist.url])
            }
            Divider()
            Button("Remove from Playlists") { remove() }
        }
        .animation(Motion.quick, value: hovering)
    }

    private var nameColour: Color {
        guard there else { return Palette.faint }
        return current ? Palette.accent : Palette.ink
    }

    /// The tracks of the folder: read from the disk, in the same order and by
    /// the same rules the player reads a folder it is asked to play, so that
    /// the list in the menu is the queue and not a second opinion about it.
    @ViewBuilder
    private var inside: some View {
        if !there {
            note("This folder is not there any more.")
        } else if tracks.isEmpty {
            note("Nothing to play in here — \(PlayerEngine.kinds) only.")
        } else {
            ForEach(Array(tracks.enumerated()), id: \.element) { place, url in
                TrackRow(
                    url: url,
                    number: place + 1,
                    playing: heard(url),
                    play: { engine.play(url, in: playlist.url) }
                )
            }
        }
    }

    /// Whether that track is the one being heard, by path: the list and the
    /// queue are the same reading of the folder (PlayerEngine.tracks), but a
    /// URL is a fussy thing to compare and the mark on the row is worth being
    /// sure about.
    private func heard(_ url: URL) -> Bool {
        guard let track = engine.track else { return false }
        return Playlist.plain(track) == Playlist.plain(url)
    }

    private func note(_ said: String) -> some View {
        Text(said)
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 28)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
    }

    /// A folder's tracks are read when its list is opened and when the menu
    /// says its reading is stale — one directory listing, on the main thread,
    /// because a listing is a listing and the disk is right there.
    private func read() {
        there = playlist.there
        guard open else { return }
        tracks = there ? PlayerEngine.tracks(in: playlist.url) : []
    }
}

/// One track of one playlist. Its name is the file's own — the tags of every
/// file in a folder are not read to draw a list, and a name is what a list is
/// for; the tags of the track that is *playing* are read by the engine, and
/// are on the window.
private struct TrackRow: View {
    let url: URL
    let number: Int
    let playing: Bool
    let play: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: play) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(playing ? Palette.accent : Palette.faint)
                    .frame(width: 16, alignment: .trailing)
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundStyle(playing ? Palette.accent : Palette.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.leading, 24)
            .padding(.trailing, 8)
            .frame(height: Metrics.row)
            .background(
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .fill(playing ? Palette.wash : (hovering ? Palette.hover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(url.lastPathComponent)
        .accessibilityLabel(url.deletingPathExtension().lastPathComponent)
        .accessibilityAddTraits(playing ? .isSelected : [])
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: playing)
    }
}
