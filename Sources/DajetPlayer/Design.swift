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
//   · `Palette.pane`, the translucent step away from the ground that a cover's
//     empty square stands on. (The window's surfaces are not colours at all
//     any more: the material gives the light theme its glass and the dark
//     theme its ground washed over the same material — Window.swift. The
//     `Palette.Glass` washes, the `Palette.side` tile and `Transparency` went
//     with them.)
//   · the few numbers that are the player's alone (`Metrics`, extended);
//   · the three looks the window wears (`Theme`) and the wave that is the
//     player's mark.

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

    /// The AppKit side of the player's own pairs, for the corners of the app
    /// that want an `NSColor` and keep it. The window's own ground is the
    /// package's `Palette.NS.ground` / `Palette.ground` — white in the light
    /// theme, the shared near-black in the dark — and the dark theme's wash
    /// over the material is that same ground, so that the opaque window of the
    /// Reduce Transparency case and the see-through one of the dark theme are
    /// one colour without a second copy of the numbers to keep in step.
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
