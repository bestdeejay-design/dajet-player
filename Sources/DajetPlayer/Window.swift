import AppKit
import SwiftUI

// The window itself, and the surface that covers it: the two things the look
// is actually made of (P-06R — the owner's final word on it — and P-10, which
// is the owner's second word about the light one).
//
//   · LIGHT — glass, over the whole surface of the window. A system material
//     does the blurring: an `NSVisualEffectView` with `behindWindow` blending,
//     which samples the *desktop* rather than the window's own contents, and a
//     window that is transparent for it to be seen through. Over the material
//     there is a lift, a sheen down from the top edge and a shadow at the
//     foot — because a blurred rectangle on its own reads as a grey rectangle
//     unless something in it says which way the light comes from.
//
//     Which material, and how much wash over it, is the whole of what P-10
//     changed here: `.menu` was too much of both. A menu's material is made to
//     be read against whatever is behind it, which means a tint and a blur
//     strong enough to flatten a desktop of any colour — and behind a whole
//     window, rather than behind four lines of a context menu, that reads as
//     frosted rather than as glass. `.underWindowBackground` is the material
//     for the background of a window's own content: the least blur of the ones
//     that still have a surface, and the one that leaves the desktop legible
//     behind it, which is what the owner asked for and what a pane of glass
//     over a desk actually does. The washes over it are lighter for the same
//     reason — a lift and a sheen are there to say which way the light comes
//     from, and a heavy one says it by making the pane milky.
//
//     (The first attempt at this version used `.underWindowBackground` too, and
//     came out as nothing at all — but that was in a window that was still
//     opaque, where a `behindWindow` material has no desktop to sample and
//     draws its own tint instead. See `WindowDress`, which is where the window
//     is told that it is not opaque.)
//
//   · DARK — matte, over the whole surface of the window. One almost-black
//     colour, opaque, with no material, no translucency and nothing grey in
//     it: the series' own dark underlay is a page ground and a whole window of
//     it read as grey. The desktop behind the window is not its business, and
//     the window says so about itself (`isOpaque`).
//
// Both of them are drawn under everything and over the whole window, the
// toolbar's band included — which is what a transparent title bar and a
// full-size content view are for — so that the look is the window and not a
// panel in it. The traffic lights keep their corner in both, the toolbar keeps
// its band, and the window's own corners are macOS's: continuous, and the same
// curve the system uses for the browser next door.

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
    /// The material the pane is: the lightest blur that is still a surface of
    /// its own, so that the desktop behind the window is what is seen through
    /// it rather than what is suggested by it. The ladder, were it ever wanted
    /// again, runs from here through `.sidebar` and `.header` to `.menu` and
    /// `.popover` — each step more tint and more blur than the last, and each
    /// one a material made for something smaller than a whole window.
    private static let material: NSVisualEffectView.Material = .underWindowBackground

    var body: some View {
        ZStack {
            // The blur, and the desktop behind it. Nothing here draws a blur of
            // its own: a system material is cheaper, sharper, and the only kind
            // that blends with what is on the other side of the window at all.
            VisualEffect(material: Self.material, blending: .behindWindow)
            // What is over it: the lift that makes a frosted pane frosted, the
            // sheen from the top edge down, and the soft shadow a pane casts
            // along its foot. All three are lighter than the first version of
            // this glass wore them, because the pane underneath is now a window
            // onto the desk rather than a wall of frost, and a heavy wash over a
            // window is a curtain.
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
                .frame(height: 120)
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
/// and with the title bar out of the way in both — which is what lets the
/// system's own toolbar sit in a band of the same glass as everything under it.
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
            // The band along the top is the system's own toolbar, and the three
            // buttons in the corner are the system's too: the band is made
            // transparent so that what shows through it is this window's own
            // surface rather than a second material laid over the first, and
            // the line the platform draws between a toolbar and its content is
            // asked not to be, because there is nothing on either side of it
            // but the same pane of glass.
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            // The window is dragged by its title bar, which is what a title bar
            // is for and what the toolbar's band is: a drag on the body takes a
            // slider, an edge or a track, and never carries the window off with
            // it. Double-clicking the band zooms, as the Mac's own System
            // Settings say it should, because the band is the system's again
            // rather than a strip that had to be taught.
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
