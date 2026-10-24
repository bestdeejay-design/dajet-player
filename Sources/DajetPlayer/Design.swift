import AppKit
import SwiftUI

// What is left of the player's own design layer now that the series has one.
//
// The colours, the distances and the springs the whole line shares live in the
// DajetUI package next door, and are opened to the whole of this target below —
// every file that says `Palette.ink` or `Metrics.side` is saying the package's,
// and says it without an import of its own. The reference for the shared
// palette is the browser's window (the owner's word, stage 4): white ground,
// one terracotta accent. The player's own warm cream is gone with that
// decision — a deliberate step in making the two apps one app twice.
//
// What remains in this file is the player's own, because no token of the
// package says it:
//
//   · the two surfaces a window is made of that have no place in a token
//     set — the light theme's glass (its washes, kept under `Palette.Glass`)
//     and the dark theme's matte (Window.swift, on the package's ground);
//   · `Palette.pane` and `Palette.side`, the two translucent steps away from
//     the ground that a cover's empty square and the side menu stand on;
//   · the few numbers that are the player's alone (`Metrics`, extended);
//   · the Reduce Motion courtesy the springs are handed back through;
//   · the three looks the window wears (`Theme`), `Transparency`, and the
//     wave that is the player's mark.

/// The series' design language — palette, metrics, radiuses, springs, the
/// door — opened to every file of the target from this one place, so that
/// nothing else has to say where its colours come from.
@_exported import DajetUI

// MARK: - the player's own palette

extension Palette {
    /// What stands where a cover would be when a file has none: a pane of its
    /// own, barely there, so that the mark over it is a mark on something and
    /// not a shape floating in the window.
    static let pane = Color(nsColor: Pair.veil(light: (1, 1, 1, 0.34), dark: (1, 1, 1, 0.045)))

    /// The side menu's own step away from whatever the window is: a little
    /// deeper than the glass in the light theme, a little lighter than the
    /// matte in the dark — one wash, and not a second material (see Side.swift).
    /// The step it takes is off the ground the way it always was; only the
    /// ground itself is the package's now.
    static let side = Color(nsColor: Pair.veil(light: (0.96, 0.97, 0.98, 0.92), dark: (0.075, 0.080, 0.090, 0.94)))

    /// The light surface's own glass: the wash that lifts a blurred pane off
    /// the desktop, the sheen across its top, and the shadow it casts at its
    /// foot. Transparent values, because they lie *over* the material and are
    /// not colours of their own (see Window.swift).
    ///
    /// All three are lighter than the first version of this glass wore them
    /// (P-10 — the owner's word on that one was "too murky"): the material
    /// under them is a window onto the desk now rather than a wall of frost,
    /// and a wash heavy enough to be seen over frost is a curtain over a
    /// window. What they are for has not changed — a pane with no lift and no
    /// sheen is a rectangle of somebody else's wallpaper — only how much of
    /// each it takes to say it.
    enum Glass {
        /// The lift: enough white for the pane to read as a pane, little
        /// enough that the desktop behind it is still what is seen through it.
        static let lift = Color.white.opacity(0.025)
        /// The sheen: the top edge catching the light, which is the one thing
        /// that says which way is up on a surface with no edges of its own.
        static let sheen = Color.white.opacity(0.07)
        /// The foot: the opposite, where the pane meets the window's lower
        /// edge and everything behind it is floor.
        static let foot = Color.black.opacity(0.022)
    }

    /// The AppKit side of the player's own pairs, for the corners of the app
    /// that want an `NSColor` and keep it. The window's own background is the
    /// package's `Palette.NS.ground` — white in the light theme, the shared
    /// near-black in the dark — so that the window behind its material and the
    /// matte drawn over it are the same colour without a second copy of the
    /// numbers to keep in step.
    enum Pair {
        /// The pair looked up by the appearance the window is in. One
        /// provider, resolved wherever the colour is drawn — which is what
        /// makes a single name right in both themes without anything having to
        /// watch for the change.
        static func tint(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
            NSColor(name: nil) { appearance in
                let colours = darkNow(appearance) ? dark : light
                return NSColor(srgbRed: colours.0, green: colours.1, blue: colours.2, alpha: 1)
            }
        }

        /// The same, for the few that are laid over something rather than
        /// being a surface of their own.
        static func veil(
            light: (CGFloat, CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat, CGFloat)
        ) -> NSColor {
            NSColor(name: nil) { appearance in
                let colours = darkNow(appearance) ? dark : light
                return NSColor(srgbRed: colours.0, green: colours.1, blue: colours.2, alpha: colours.3)
            }
        }

        private static func darkNow(_ appearance: NSAppearance) -> Bool {
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    }
}

// MARK: - the player's own numbers

/// The distances the window is laid out by. The ones the whole series shares
/// — the door, the row, the column's width and its range — are the package's
/// `Metrics`; these are the player's alone, said here as an extension so that
/// one name still says them all.
extension Metrics {
    /// The strip a hand and the keyboard land on around the progress line:
    /// the line is the drawing, this is the hit zone — sixteen points, the
    /// least the platform's own controls would carry (issue #15).
    static let scrubStrip: CGFloat = 16
    /// The air above the column's first row, now that the column has no band of
    /// its own to hold it away from the toolbar.
    static let gap: CGFloat = 10
    /// The floor of Custom, which has no template to name a width of its own:
    /// the narrowest the player in a Custom window is ever squeezed to. The
    /// templates need no floor of this kind — beside the column their player
    /// keeps its template's own width, and the window's minimum is built on
    /// that (see Presentation.contentMinWidth, issue #16).
    static let playerMin: CGFloat = 200
    /// The width from which the foot of the window has room for all seven of
    /// its controls on one row — the two modes, the three hands and the volume,
    /// with the air between them that makes a row of buttons readable rather
    /// than a bar of teeth. Below it they are the same seven on two rows, and
    /// nothing is dropped, hidden or squeezed off the end (P-10).
    static let roomy: CGFloat = 500
    /// The sleeve: how large it may be on a large window. A picture is the
    /// only thing in this window that is allowed to be that big, and on a
    /// small window it is as big as there is room for and no larger.
    static let sleeve: CGFloat = 272
}

// MARK: - the player's own motion

// The package's tempos are already `Animation?` that turn into nothing at all
// when the Mac has been asked for less movement — `Motion.reduced` is public
// there, which is what the tray's dance reads. No wrapper of the player's own:
// the app asks for `Motion.settle` and `Motion.quick` directly.

// MARK: - the looks

/// The player's own dressing on the line's one `Look`: the words and glyphs
/// its switch and tray wear. The axis itself — light, dark, or the Mac's —
/// lives in the package, remembered under the one key the whole line shares;
/// the window's surface follows the appearance the look puts on the app
/// (light is the glass, dark the matte), and nothing here knows about window
/// templates: a look change is a coat, not a re-layout.
extension Look {
    /// What the tray and the switch say for each look.
    var title: String {
        switch self {
        case .light: return "Light — glass"
        case .dark: return "Dark — matte"
        case .system: return "Follow the Mac"
        }
    }

    /// The glyph the switch in the window's corner wears for this look.
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// The other one, for the button that walks the three of them round.
    var next: Look {
        switch self {
        case .light: return .dark
        case .dark: return .system
        case .system: return .light
        }
    }
}

/// Whether the Mac has been asked for less transparency (System Settings ›
/// Accessibility › Display). The glass is a courtesy and not a feature: with
/// the setting on, the light window is drawn as a solid pale surface instead,
/// which is what every system window does with its own materials.
///
/// Read afresh every time it is asked, rather than once: System Settings is
/// allowed to change while a player is open.
enum Transparency {
    static var allowed: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
}

// MARK: - the mark

/// The player's own mark: one wave, drawn from a path rather than loaded from
/// a file, so it stays crisp at any size. The browser's mark is a letter; this
/// one is what the player does with the sound, and it is the same wave the
/// release icon is planned around (a wave over the almost-black, in the
/// terracotta).
struct Wave: Shape {
    /// How many crests across the width, and how tall they are.
    var crests: Double = 2
    var height: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }
        let middle = rect.midY
        let amplitude = rect.height * height / 2
        // Sixty-four steps across: finer than any eye at any size this is
        // drawn at, and a polyline the window never has to think about.
        let steps = 64
        path.move(to: CGPoint(x: rect.minX, y: middle))
        for step in 1...steps {
            let along = Double(step) / Double(steps)
            let x = rect.minX + rect.width * CGFloat(along)
            let y = middle - CGFloat(sin(along * 2 * .pi * crests)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}
