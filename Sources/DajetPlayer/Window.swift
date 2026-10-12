import AppKit
import SwiftUI

// The window itself, and the surface that covers it: the two things the look
// is actually made of (P-06R — the owner's final word on it).
//
//   · LIGHT — glass, over the whole surface of the window. A system material
//     does the blurring: an `NSVisualEffectView` with `behindWindow` blending,
//     which samples the *desktop* rather than the window's own contents, and a
//     window that is transparent for it to be seen through. Over the material
//     there is a lift, a sheen down from the top edge and a shadow at the
//     foot — because a blurred rectangle on its own reads as a grey rectangle
//     unless something in it says which way the light comes from. This is the
//     part the first attempt at this version got wrong: the material was put
//     in without the wash over it and without a window to see the desktop
//     through, and it came out as a flat surface nobody would call glass.
//
//   · DARK — matte, over the whole surface of the window. One almost-black
//     colour, opaque, with no material, no translucency and nothing grey in
//     it: the series' own dark underlay is a page ground and a whole window of
//     it read as grey. The desktop behind the window is not its business, and
//     the window says so about itself (`isOpaque`).
//
// Both of them are drawn under everything and over the whole window, the
// title bar's band included — which is what a transparent title bar and a
// full-size content view are for — so that the look is the window and not a
// panel in it. The traffic lights keep their corner in both, and the window's
// own corners are macOS's: continuous, and the same curve the system uses for
// the browser next door.

/// The whole surface of the window, under everything it shows.
struct Surface: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if scheme == .light, Transparency.allowed {
                Glass()
            } else {
                Matte()
            }
        }
        .ignoresSafeArea()
    }
}

/// The light theme: one pane of glass over the whole window.
private struct Glass: View {
    var body: some View {
        ZStack {
            // The blur, and the desktop behind it. Nothing here draws a blur
            // of its own: a system material is cheaper, sharper, and the only
            // kind that blends with what is on the other side of the window
            // at all.
            //
            // Which material is not a detail. `.underWindowBackground` is what
            // a transparent window's *background* is read through, and in this
            // window it came out as nothing at all (the first attempt at this
            // version used it, and the owner's word for the result was: no
            // glass). `.menu` is a material with a surface of its own — a tint
            // and a blur strong enough to be seen over a desktop of any
            // colour — and it is the one the browser's own glass panel wears
            // (dajet-browser, SiteCard.swift), so the two apps fog the same
            // way. The light comes from above in the two washes over it.
            VisualEffect(material: .menu, blending: .behindWindow)
            // What is over it: the lift that makes a frosted pane frosted, the
            // sheen from the top edge down, and the soft shadow a pane casts
            // along its foot.
            Palette.Glass.lift
            LinearGradient(
                colors: [Palette.Glass.sheen, Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.clear, Palette.Glass.foot],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The dark theme: one flat, opaque, almost-black surface over the whole
/// window, with the shadow of a vertical gradient on it so that it reads as a
/// surface rather than as a fill — and nothing else at all.
private struct Matte: View {
    var body: some View {
        ZStack {
            Palette.ground
            LinearGradient(
                colors: [Color.black.opacity(0.32), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

/// One system material, filling whatever it is given.
///
/// `behindWindow` is the blending that samples the desktop rather than the
/// window's own contents, and it is the whole difference between glass and a
/// grey panel. It only means anything inside a window that is not opaque — see
/// `WindowDress`, which is where the window is told that it is not.
struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NeverInTheWay()
        view.material = material
        view.blendingMode = blending
        // Active rather than following the window: a player left open behind
        // another window is a player being listened to, and its surface should
        // not go flat just because the app in front is somebody else's.
        view.state = .active
        view.isEmphasized = false
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        // Only when it is a different one: SwiftUI asks this again after every
        // update of the window's body — the progress bar ticks its way through
        // a track several times a second — and setting a material that is
        // already set asks the compositor to do the blur again for nothing.
        if view.material != material { view.material = material }
        if view.blendingMode != blending { view.blendingMode = blending }
    }

    /// A background is a background: the window takes the clicks and the drops
    /// that land on it. A real view under SwiftUI's drawing still answers the
    /// hit test first, so this one refuses it outright — the browser's own
    /// probes do the same, and for the same reason.
    final class NeverInTheWay: NSVisualEffectView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// The window itself, told what the surface is: transparent where the glass
/// needs the desktop behind it, opaque where the matte is the whole window,
/// and with the title bar out of the way in both.
///
/// It is set from a real view inside the window, because that is the only
/// place SwiftUI lets an app reach its own window from — and it is set again
/// every time the look changes, and once more on the run loop after the window
/// exists, because a window is still being put together when the view first
/// arrives and SwiftUI will happily put its own idea of the background back
/// over anything set too early. The browser learned the same lesson (its
/// WindowSetup says so); this is its recipe.
struct WindowDress: NSViewRepresentable {
    /// The look that is on, resolved: true when the light one is, whose
    /// surface is glass and whose window therefore has to be see-through.
    let glass: Bool

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ view: Probe, context: Context) {
        view.glass = glass
    }

    final class Probe: NSView {
        var glass = false {
            // And again only when it is a different one: dressing the window
            // is cheap, but it is not free, and this is handed the same value
            // on every one of the window's many redraws.
            didSet {
                guard glass != oldValue else { return }
                dress()
            }
        }

        /// Here only to learn the window, never to take a click.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            // The window is still being put together at this point; anything
            // set now can be overwritten a moment later. (On the main queue
            // and said so: a closure handed to a queue is not a place the
            // compiler believes is the main actor, whatever the queue is.)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { [weak self] in self?.dress() }
            }
        }

        private func dress() {
            guard let window else { return }
            // The band along the top is ours; the three buttons in the corner
            // are the system's, and stay exactly where macOS keeps them.
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            // The window is dragged by the strip in the band (see DragStrip),
            // and by nothing else: a drag that means to take a slider, an edge
            // or a track must never carry the window off with it.
            window.isMovableByWindowBackground = false
            window.isMovable = true
            window.hasShadow = true
            if glass, Transparency.allowed {
                // Non-opaque and clear. There is no other way: an opaque
                // window has nothing behind it for a material to blur, and
                // that is what "the glass is not visible" comes down to.
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                // Matte, or glass where the Mac has asked for less
                // transparency: the whole window is this one colour, and the
                // desktop behind it is nobody's business. The colour resolves
                // itself against the appearance the window is in.
                window.isOpaque = true
                window.backgroundColor = Palette.Pair.ground
            }
        }
    }
}

/// The band along the top of the window: drag it to move the window,
/// double-click it to fill the screen, drop music on it to play it.
///
/// With the title bar hidden, nothing that is left in the band answers a drag
/// — the interface swallows the clicks a title bar would have handled, and
/// they have to be put back. They are put back here rather than with
/// `isMovableByWindowBackground`, which would make a drag on the progress bar
/// mean "move the window".
///
/// A real view sits under SwiftUI's drawing and takes the click first, so the
/// runs of the band that belong to something drawn in them — the traffic
/// lights, the toggle beside them, the buttons at the other end — are refused,
/// and the click falls through to what is there. The browser's DragStrip is
/// this view, to the letter.
struct DragStrip: NSViewRepresentable {
    /// The run at the leading end that belongs to whatever is drawn there.
    var leading: CGFloat = 0
    /// The run at the trailing end that belongs to a button.
    var trailing: CGFloat = 0
    /// Music dropped on the band, in the same words the window's own drop
    /// speaks: a real view takes the drag as well as the click, and without
    /// this the band would simply swallow a folder let go over it.
    var files: ([URL]) -> Void = { _ in }
    /// Something is being dragged over the band, or has left it.
    var targeted: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> Strip { Strip() }

    func updateNSView(_ view: Strip, context: Context) {
        view.leading = leading
        view.trailing = trailing
        view.files = files
        view.targeted = targeted
    }

    final class Strip: NSView {
        var leading: CGFloat = 0
        var trailing: CGFloat = 0
        var files: ([URL]) -> Void = { _ in }
        var targeted: (Bool) -> Void = { _ in }

        private var pressed: NSEvent?
        private var moved = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            registerForDraggedTypes([.fileURL])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        /// The strip moves the window and answers the double-click itself.
        /// Left to say yes, AppKit takes both on too, and a double-click
        /// answered twice — by AppKit on the press, here on the release —
        /// ends where it started.
        override var mouseDownCanMoveWindow: Bool { false }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let inside = convert(point, from: superview)
            guard inside.x >= leading, inside.x <= bounds.width - trailing else { return nil }
            return super.hitTest(point)
        }

        override func mouseDown(with event: NSEvent) {
            pressed = event
            moved = false
        }

        /// A little slack, so a shaky click is still a click; past it, the
        /// drag is handed to the system's own window drag, which is what makes
        /// it snap and tile the way any window does.
        override func mouseDragged(with event: NSEvent) {
            guard let window, let pressed, !moved else { return }
            let dx = event.locationInWindow.x - pressed.locationInWindow.x
            let dy = event.locationInWindow.y - pressed.locationInWindow.y
            if abs(dx) < 3 && abs(dy) < 3 { return }
            moved = true
            window.isMovable = true
            window.performDrag(with: pressed)
        }

        /// A double-click does what a title bar's does, following the Mac's
        /// own System Settings › Desktop & Dock › double-click a title bar.
        override func mouseUp(with event: NSEvent) {
            guard let window, !moved, event.clickCount == 2 else { return }
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window.miniaturize(nil)
            case "None": break
            default: window.zoom(nil)
            }
        }

        // MARK: - what is dropped on it

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard !brought(sender).isEmpty else { return [] }
            targeted(true)
            return .copy
        }

        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            brought(sender).isEmpty ? [] : .copy
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            targeted(false)
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            targeted(false)
            let found = brought(sender)
            guard !found.isEmpty else { return false }
            files(found)
            return true
        }

        /// The files a drag is carrying, and nothing else: an address dragged
        /// out of a browser is not a file URL, is not accepted, and never
        /// reaches the player.
        private func brought(_ sender: NSDraggingInfo) -> [URL] {
            let board = sender.draggingPasteboard
            let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
            return (board.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
        }
    }
}
