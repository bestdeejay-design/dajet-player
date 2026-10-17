import AppKit
import SwiftUI

// The look of the «dajet» version: the colours, the distances, and the two
// springs the whole window moves on. Nothing in here plays anything — the
// engine never reads it, and all of it is the window's business.
//
// It is written the way the browser next door writes its own
// (dajet-browser/Sources/Dajet/Design.swift): every colour is a *pair* — one
// for a light window, one for a dark one — and resolves itself against the
// appearance the window is in, so one name is right in both. What is the
// player's own is what each of the two *is*, and that is the final decision of
// the owner (P-06R):
//
//   · the light window is glass over the whole of its surface — the desktop
//     behind it, blurred, lifted, and cut with continuous corners (the recipe
//     lives in Window.swift);
//   · the dark window is matte: one almost-black surface, opaque, with nothing
//     of the desktop in it and nothing grey about it. The series' own dark
//     underlay (#15181C) is a *page* ground — something drawn inside a window
//     — and a whole window of it reads as grey. It is not used here.
//
// The terracotta is the series': the single colour that marks what is playing.

enum Palette {
    /// The window's own ground: what there is where there is no glass, and
    /// what the light window falls back to when the Mac has been asked to
    /// reduce transparency.
    static let ground = Color(nsColor: Pair.ground)
    /// Text, and the glyphs that are read as text.
    static let ink = Color(nsColor: Pair.ink)
    /// What is said under the ink: an artist under a title, a rest state.
    static let muted = Color(nsColor: Pair.muted)
    /// What is barely said: a disabled control, a name under a name.
    static let faint = Color(nsColor: Pair.faint)
    /// A line between two things: the side menu's edge, the foot of the bar.
    static let hairline = Color(nsColor: Pair.hairline)
    /// A row with the pointer over it.
    static let hover = Color(nsColor: Pair.hover)
    /// A row that is what is on *now*: the folder being played, the track
    /// being heard.
    static let wash = Color(nsColor: Pair.wash)
    /// The series' terracotta, in both themes: deeper on glass where a pale
    /// peach would not be read, and the pale peach on the near-black.
    static let accent = Color(nsColor: Pair.accent)
    /// What stands where a cover would be when a file has none: a pane of its
    /// own, barely there, so that the mark over it is a mark on something and
    /// not a shape floating in the window.
    static let pane = Color(nsColor: Pair.pane)
    /// The side menu's own step away from whatever the window is: a little
    /// deeper than the glass in the light theme, a little lighter than the
    /// matte in the dark — one wash, and not a second material (see Side.swift).
    static let side = Color(nsColor: Pair.side)
    /// What is drawn on top of the accent itself — the play button's glyph.
    static let onAccent = Color(nsColor: Pair.onAccent)

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

    /// The pairs themselves, for the AppKit corners of the app that want an
    /// `NSColor` and keep it: the window's background, the side menu's layer.
    enum Pair {
        /// The series' almost-black for a dark window, and the series' own
        /// warm off-white for the light one's solid fallback.
        static let ground = tint(light: (0.957, 0.945, 0.910), dark: (0.039, 0.043, 0.051))
        /// The series' ink and its reverse: #16181C on the light side, the
        /// series' #F4F1E8 text on the dark.
        static let ink = tint(light: (0.086, 0.094, 0.110), dark: (0.957, 0.945, 0.910))
        static let muted = tint(light: (0.420, 0.427, 0.443), dark: (0.655, 0.647, 0.624))
        static let faint = tint(light: (0.600, 0.608, 0.624), dark: (0.451, 0.451, 0.443))
        /// A hairline is a black line on a light window and a white one on a
        /// dark, and neither of them is ever quite opaque.
        static let hairline = veil(light: (0, 0, 0, 0.10), dark: (1, 1, 1, 0.09))
        static let hover = veil(light: (0, 0, 0, 0.045), dark: (1, 1, 1, 0.055))
        /// The current row: the accent, laid in so faintly that the name on
        /// it is still the thing read.
        static let wash = veil(light: (0.757, 0.329, 0.169, 0.10), dark: (0.910, 0.682, 0.549, 0.14))
        static let accent = tint(light: (0.757, 0.329, 0.169), dark: (0.910, 0.682, 0.549))
        static let pane = veil(light: (1, 1, 1, 0.34), dark: (1, 1, 1, 0.045))
        /// One step off the ground, the way the browser's own column is: toward
        /// the ink in both themes, which is deeper on the light side and
        /// lighter on the dark.
        static let side = veil(light: (0.96, 0.97, 0.98, 0.92), dark: (0.075, 0.080, 0.090, 0.94))
        static let onAccent = tint(light: (1.0, 1.0, 1.0), dark: (0.055, 0.059, 0.067))

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

/// The distances the window is laid out by. The browser's own numbers where
/// they are the same thing — the column's width, the corner, the strip — so
/// that the two apps are the same app twice.
///
/// Two numbers that used to be here are gone (P-10): the height of a band
/// along the top of the window, and where the traffic lights end. Both were
/// this app measuring the system's own furniture with a ruler, so that a band
/// of its own could sit in the same place and leave the same air — and both
/// became nothing at all the moment the band became the platform's toolbar,
/// which is where the traffic lights are and knows it without being told.
enum Metrics {
    /// One round button in the window, and the size a hand expects one at.
    static let door: CGFloat = 26
    /// The side menu: the width it rests at, and the two it lives between. The
    /// split view is handed the range (App.swift) and its divider does the
    /// rest; the resting width is what the column comes out at, and is also
    /// the smallest window this player has — a formal square of it, and the
    /// reason a window can never be narrower than the column that belongs in
    /// it (see App.swift).
    static let side: CGFloat = 232
    static let sideMin: CGFloat = 176
    static let sideMax: CGFloat = 440
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
    /// One row of the side menu, and the corner every panel in the window is
    /// cut with — the browser's row and the browser's curve.
    static let row: CGFloat = 26
    static let corner: CGFloat = 8
    static let panel: CGFloat = 12
}

// One spring for anything that arrives or leaves, and one flick for a thing
// under the pointer. There used to be a third, the column's own glide, and it
// is gone with the drawer it moved: the column is the split view's element
// now, and opening and closing it is the system's own motion (issue #15).
// Using the same two everywhere is most of why a thing feels like a single
// piece of software rather than a pile of views — the browser's words, and
// its numbers. With macOS Reduce Motion on, transitions become immediate.
enum Motion {
    /// Whether the interface should move at all, following the Mac's own
    /// accessibility setting.
    static var reduced: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static var settle: Animation? {
        reduced ? nil : .spring(response: 0.30, dampingFraction: 0.86)
    }

    static var quick: Animation? {
        reduced ? nil : .easeOut(duration: 0.14)
    }

    /// A transition that is nothing at all when the Mac has asked for still.
    static func honoured(_ animation: Animation?) -> Animation? {
        reduced ? nil : animation
    }
}

/// Which of the two looks the window wears, and whether the Mac decides.
///
/// The browser has three (Settings › Appearance) and so does this: a player
/// that can only be looked at one way is a player that has an opinion about
/// your desktop. The choice is remembered between runs, and the window follows
/// it at once.
enum Theme: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    /// The key the choice lives under, in the app's own little corner of the
    /// standard defaults. One string, on this Mac, for this app.
    static let key = "look"

    var title: String {
        switch self {
        case .light: return "Light — glass"
        case .dark: return "Dark — matte"
        case .system: return "Follow the Mac"
        }
    }

    /// The glyph the switch in the window's corner wears for this look: what
    /// is on, said in one shape.
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// The look last chosen, or the Mac's own when nothing has been chosen —
    /// which is where a fresh copy of the app starts, as the browser does.
    static var remembered: Theme {
        Theme(rawValue: UserDefaults.standard.string(forKey: Theme.key) ?? "") ?? .system
    }

    /// What the app is told to be. Nothing at all for `system`: the app then
    /// follows the Mac, and changes with it.
    var appearance: NSAppearance? {
        switch self {
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        case .system: return nil
        }
    }

    /// The other one, for the button that walks the three of them round.
    var next: Theme {
        switch self {
        case .light: return .dark
        case .dark: return .system
        case .system: return .light
        }
    }

    /// Set on the app rather than on the window, so every panel, alert and
    /// sheet — the folder panel included — agrees with the window it was
    /// opened from.
    ///
    /// Never from inside whatever is happening when it is asked for: the
    /// switch is pressed from within an animation, and re-skinning every
    /// window in the middle of one is how a window ends up with a layer that
    /// takes clicks and shows nothing. The browser learned that the hard way
    /// (its Design.swift says so, and this is its own `Look.apply()`, to the
    /// line): the next turn of the run loop is soon enough here too.
    ///
    /// Deliberately not main-actor-isolated, so that it can be asked for from
    /// anywhere — a view's `onAppear`, the app's own `init` — and does its own
    /// hopping. It touches nothing but the app's appearance, and that on the
    /// main queue.
    func apply() {
        let wanted = appearance
        DispatchQueue.main.async {
            guard NSApp.appearance !== wanted, NSApp.appearance?.name != wanted?.name else { return }
            NSApp.appearance = wanted
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

/// One button: a glyph in a rounded square, washed under the pointer, and in
/// the accent while it is on. The browser's own door (its Side.swift), at the
/// same size and with the same curve, so that a hand that knows one window
/// knows the other.
struct Door: View {
    let icon: String
    var help = ""
    var on = false
    var size: CGFloat = Metrics.door
    var glyph: CGFloat = 11
    /// A door that cannot be opened still stands where it is, greyed — a row
    /// that loses its buttons when there is nothing to press is a row that
    /// moves about while it is being read.
    var enabled = true
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            Image(systemName: icon)
                .font(.system(size: glyph, weight: .medium))
                .foregroundStyle(colour)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                        .fill(on ? Palette.wash : (hovering && enabled ? Palette.hover : Color.clear))
                )
                .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        }
        // Borderless rather than plain: the door is drawn by what is above,
        // and what the platform owes a button — the pressed state, the focus
        // ring under Full Keyboard Access, the seat in the responder chain —
        // comes from the style, not from this view (issue #15). The wash the
        // pointer sees stays this window's own.
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .onHover { hovering = $0 }
        .help(help)
        // What VoiceOver is told: the door's own word when it has one, and
        // the glyph's name, said the way a person would, when it has not.
        .accessibilityLabel(help.isEmpty
                            ? Text(icon.replacingOccurrences(of: ".", with: " "))
                            : Text(help))
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: on)
    }

    private var colour: Color {
        guard enabled else { return Palette.faint }
        if on { return Palette.accent }
        return hovering ? Palette.ink.opacity(0.8) : Palette.muted
    }
}

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
