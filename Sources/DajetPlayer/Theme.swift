import AppKit
import SwiftUI

// The two skins of the «dajet» version: a dark one and a light one. Nothing
// here plays anything — it is the part of the window that is only how it
// looks, and the engine never reads it.
//
// The dark skin is a matte base, the colour of the Dajet site, with no glass
// and no material effect in it at all. The light skin is the one that wears
// glass: a native `NSVisualEffectView` behind the window, blending with what
// is on the desktop behind it. Light glass and dark matte are two different
// things here, and the window never mixes them.

/// Which of the two skins is on. Remembered between runs under one key.
enum Theme: String, CaseIterable {
    case dark
    case light

    /// The key in the standard defaults the choice lives under.
    static let key = "theme"

    var scheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }

    /// Whether this skin wears glass. Only the light one does.
    var glass: Bool { self == .light }

    /// The other one, for the button that switches between them.
    var other: Theme { self == .dark ? .light : .dark }
}

/// The colours of one skin, written out rather than left to the system's
/// semantic ones, so that the two skins look the way they were drawn and not
/// the way the appearance around them happens to be.
struct Palette {
    /// The window's own colour behind everything, where there is no glass.
    let base: NSColor
    let text: Color
    let secondary: Color
    /// The terracotta of Dajet: the one colour that marks what is on.
    let accent: Color
    /// The thin line along the foot of the window, and the bar it fills.
    let track: Color
    /// A row of the list that is playing: a tint of the accent, quiet enough
    /// to read the title on either skin.
    let current: Color
    /// What sits behind the list: nothing in the dark, a faint veil of the
    /// light glass in the light.
    let panel: Color

    static func of(_ theme: Theme) -> Palette {
        switch theme {
        case .dark:
            return Palette(
                base: NSColor(srgbRed: 0x15 / 255, green: 0x18 / 255, blue: 0x1C / 255, alpha: 1),
                text: Color(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xE8 / 255),
                secondary: Color(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xE8 / 255).opacity(0.6),
                accent: Color(red: 0xE8 / 255, green: 0xAE / 255, blue: 0x8C / 255),
                track: Color.white.opacity(0.12),
                current: Color(red: 0xE8 / 255, green: 0xAE / 255, blue: 0x8C / 255).opacity(0.16),
                panel: Color.white.opacity(0.04)
            )
        case .light:
            // The accent is darkened for the light skin: the dark skin's
            // terracotta is a pale peach, and on glass it would not be read.
            return Palette(
                base: .clear,
                text: Color(red: 0x1B / 255, green: 0x1D / 255, blue: 0x21 / 255),
                secondary: Color(red: 0x1B / 255, green: 0x1D / 255, blue: 0x21 / 255).opacity(0.6),
                accent: Color(red: 0xA9 / 255, green: 0x47 / 255, blue: 0x2A / 255),
                track: Color.black.opacity(0.12),
                current: Color(red: 0xA9 / 255, green: 0x47 / 255, blue: 0x2A / 255).opacity(0.14),
                panel: Color.white.opacity(0.22)
            )
        }
    }
}

/// The glass of the light skin: one native visual effect view behind the
/// whole window, blending with the desktop behind it. It is a system material
/// and nothing drawn: no border, no glow, no picture of its own.
///
/// It is put in only while the light skin is on. The dark skin does not have
/// it at all, so there is no material being composited behind a matte base.
struct LightGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        // Pinned to the light appearance, whatever the window says: this view
        // is the light skin and nothing else.
        view.appearance = NSAppearance(named: .aqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Keeps the window itself in step with the skin: a transparent window for the
/// glass to show through, and an opaque one in the matte colour for the dark
/// skin. Zero size, and nothing drawn; it only has the window to talk to.
struct WindowTone: NSViewRepresentable {
    let theme: Theme

    func makeNSView(context: Context) -> ToneView { ToneView() }

    func updateNSView(_ view: ToneView, context: Context) {
        view.theme = theme
    }

    final class ToneView: NSView {
        var theme: Theme = .dark {
            didSet { apply() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            guard let window else { return }
            if theme.glass {
                window.isOpaque = false
                window.backgroundColor = .clear
            } else {
                window.isOpaque = true
                window.backgroundColor = Palette.of(.dark).base
            }
        }
    }
}
