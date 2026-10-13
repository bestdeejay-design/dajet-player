import AppKit
import SwiftUI

// One public AppKit behind-window material, not stacked materials or private
// blur filters. P-10R reduces the veil and confines the highlights to the rim;
// the compositor still owns backdrop sampling. The result must be accepted on
// the owner's wallpaper — public AppKit does not expose a refraction radius.
// Dark matte and the opaque accessibility fallback do not use this recipe.

/// The whole surface of the window, under everything it shows.
struct Surface: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if scheme == .light, !reduceTransparency {
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
    /// Keep the macOS 14-compatible material but lower its opacity and washes.
    /// No unsupported NSGlassEffectView availability guesses or private APIs.
    private static let material: NSVisualEffectView.Material = .underWindowBackground

    var body: some View {
        ZStack {
            // The blur, and the desktop behind it. Nothing here draws a blur of
            // its own: a system material is cheaper, sharper, and the only kind
            // that blends with what is on the other side of the window at all.
            VisualEffect(material: Self.material, blending: .behindWindow, density: 0.78)
            // Thin optical cues rather than a full-height white curtain.
            Palette.Glass.lift
            LinearGradient(
                colors: [Palette.Glass.sheen, Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
            .frame(maxHeight: .infinity, alignment: .top)
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
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.04), .black.opacity(0.08)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
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
    var density: CGFloat = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NeverInTheWay()
        view.alphaValue = density
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
        if view.alphaValue != density { view.alphaValue = density }
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
    let presentation: Presentation

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ view: Probe, context: Context) {
        view.presentation = presentation
        view.glass = glass
    }

    final class Probe: NSView {
        weak var presentation: Presentation?
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
                MainActor.assumeIsolated { [weak self] in
                    guard let self else { return }
                    self.dress()
                    if let window = self.window { self.presentation?.attach(window) }
                }
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
