import AppKit
import SwiftUI

// One public AppKit behind-window material, and nothing drawn over it. The
// material owns the blur, the light along the top edge and the weight at the
// foot; the window owns the focus state the material follows; the app owns one
// wash for the dark theme and nothing else. The five drawn layers that used to
// sit over this pane (a lift, a sheen, a foot, a rim and, in the dark, a matte
// gradient — P5 spec, A.1) were the app imitating what the material already
// does, and none of them could know the colour of the desk the window is on.
// They are gone. The public AppKit surface still does not expose a refraction
// radius, so what is left must be accepted on the owner's wallpaper as it is.

/// The whole surface of the window, under everything it shows.
///
/// One material in both themes. What the dark theme adds is a wash of the
/// series' ground over that material rather than a surface of its own: the
/// window keeps answering to the desk behind it, to the Mac's focus, to Reduce
/// Transparency and to Increase Contrast, and the only thing the app decides is
/// how much of the ground it lays on top (P5 spec, C.6, variant B).
struct Surface: View {
    @Environment(\.colorScheme) private var scheme

    /// How much of `Palette.ground` the dark theme lays over the material.
    ///
    /// One named number, because it is one knob and the one thing in this file
    /// that may need tuning: on busy wallpaper it wants to go up, on a dark
    /// desk down, and at `1` the dark window is the flat, opaque matte it wore
    /// before this wave (P5 spec, C.6). The light theme lays nothing over the
    /// material at all.
    private static let matteDensity: CGFloat = 0.92

    var body: some View {
        ZStack {
            // The blur, and the desktop behind it. Nothing here draws a blur of
            // its own: a system material is cheaper, sharper, and the only kind
            // that blends with what is on the other side of the window at all.
            // `underWindowBackground` is the material documented for this
            // place — a view that should read as the back of the window having
            // peeled away — and `behindWindow` is what makes it sample the desk
            // rather than the window's own contents.
            VisualEffect(material: .underWindowBackground, blending: .behindWindow)
            if scheme == .dark {
                Palette.ground.opacity(Self.matteDensity)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// One system material, filling whatever it is given.
///
/// `behindWindow` is the blending that samples the desktop rather than the
/// window's own contents, and it is the whole difference between glass and a
/// grey panel. It only means anything inside a window that is not opaque — see
/// `WindowDress`, which is where the window is told that it is not.
///
/// There is no density here because materials do not have one: AppKit's
/// `Material` is a set of purposes, not of thicknesses, and a view `alphaValue`
/// is not a thicker material but a half-transparent picture of one. Where the
/// window wants more ground it lays a colour, as the dark theme does in
/// `Surface`.
struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NeverInTheWay()
        view.material = material
        view.blendingMode = blending
        // Following the window, which is the platform's default said out loud:
        // a surface that stays lit while the traffic lights and the toolbar
        // have gone flat is a window in two focus states at once, and the flat
        // one is the true one (P5 spec, A.7). A player left playing behind
        // another app is still a window that is not the front one, and the Mac
        // says so in one movement.
        view.state = .followsWindowActiveState
        // Emphasis is first-responder business, not beauty's.
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

/// The window itself, told what the surface is: transparent so that the
/// material has the desktop to work with, opaque when the Mac has asked for
/// less transparency — which is the window's contract and the only branch left
/// of the seven the surfaces used to have — and with the title bar out of the
/// way in both, which is what lets the system's own toolbar sit in a band of the
/// same material as everything under it.
///
/// It is set from a real view inside the window, because that is the only
/// place SwiftUI lets an app reach its own window from — and it is set again
/// every time the look changes, and once more on the run loop after the window
/// exists, because a window is still being put together when the view first
/// arrives and SwiftUI will happily put its own idea of the background back
/// over anything set too early. The browser learned the same lesson (its
/// WindowSetup says so); this is its recipe.
struct WindowDress: NSViewRepresentable {
    /// Whether the Mac has been asked for less transparency (System Settings ›
    /// Accessibility › Display). `solid`, because `opaque` is NSView's own word
    /// and this view is an NSView (and because what it asks for is a window with
    /// nothing behind it for the material to sample).
    ///
    /// This is the whole of the app's answer to that setting, and it stops at
    /// the window, which is as far as the contract goes: "if this property's
    /// value is true, UI (mainly window) backgrounds should not be
    /// semi-transparent; they should be opaque" (`NSAccessibility.h`). The
    /// materials themselves are the platform's to thicken, and it does — what
    /// the app must not do is swap its surface for a different one, which is
    /// what seven manual reads and two copied sources of the same truth used to
    /// amount to (P5 spec, A.4).
    let solid: Bool
    let presentation: Presentation

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ view: Probe, context: Context) {
        view.presentation = presentation
        view.solid = solid
    }

    final class Probe: NSView {
        weak var presentation: Presentation?
        var solid = false {
            // And again only when it is a different one: dressing the window
            // is cheap, but it is not free, and this is handed the same value
            // on every one of the window's many redraws.
            didSet {
                guard solid != oldValue else { return }
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
            // but the same pane of material.
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
            if solid {
                // Less transparency, asked for by the Mac: the whole window is
                // this one colour and the desktop behind it is nobody's
                // business. The material over it is the platform's own, and
                // the platform thickens it further by itself.
                window.isOpaque = true
                window.backgroundColor = Palette.NS.ground
            } else {
                // Non-opaque and clear. There is no other way: an opaque
                // window has nothing behind it for a material to blur, and
                // that is what "the glass is not visible" comes down to. The
                // dark theme's ground is laid over the material in `Surface`,
                // not here — the window stays see-through, and the material
                // keeps its focus, its accessibility and its desktop tinting.
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }
}
