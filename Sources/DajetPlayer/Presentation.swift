import AppKit
import Combine

/// Frame sizes, not SwiftUI content sizes: the system toolbar owns 52 pt.
/// Custom is deliberately not a third template and never snaps to a neighbour.
enum WindowTemplate: String, CaseIterable {
    case horizontal, vertical, custom

    var title: String {
        switch self {
        case .horizontal: return "Horizontal — 548 × 284"
        case .vertical: return "Vertical — 232 × 441"
        case .custom: return "Custom"
        }
    }

    var frameSize: NSSize? {
        switch self {
        case .horizontal: return NSSize(width: 548, height: 284)
        case .vertical: return NSSize(width: 232, height: 441)
        case .custom: return nil
        }
    }

    /// The band the system's own toolbar owns. Frame sizes carry it and the
    /// content the SwiftUI scene asks for by default does not; asked for by
    /// name rather than measured, because the band is the system's and its
    /// height is the system's too.
    static let toolbarChrome: CGFloat = 52

    static var initialContentSize: NSSize {
        let remembered = WindowTemplate(rawValue: UserDefaults.standard.string(forKey: AppearancePreferences.template) ?? "")
        guard let frame = remembered?.frameSize else { return NSSize(width: 560, height: 420) }
        return NSSize(width: frame.width, height: frame.height - toolbarChrome)
    }

    // Local to the templates; the old dynamic window keeps Metrics.side*.
    static let sideRest = 200.0
    static let sideRange = 176.0...240.0
}

enum AppearancePreferences {
    static let template = "windowTemplate"
    static let preset = "appearancePreset"
    static let frame = "customWindowFrame"
    static let side = "templateSideWidth"

    /// Standard defaults are ru.dajet.player in the app bundle, beside `look`.
    /// Do not register defaults before checking: that would hide an upgrade.
    static func prepare(_ defaults: UserDefaults = .standard) {
        // The old second axis — an appearance preset that bundled a look with
        // a window template — is gone. A preset an old copy remembered becomes
        // the look it stood for, and the key leaves; idempotent by removal.
        if let old = defaults.string(forKey: preset) {
            if defaults.object(forKey: Look.key) == nil {
                let look: String
                switch old {
                case "aero": look = "light"
                case "obsidian": look = "dark"
                default: look = "system"
                }
                defaults.set(look, forKey: Look.key)
            }
            defaults.removeObject(forKey: preset)
        }
        guard defaults.object(forKey: template) == nil else { return }
        let oldKeys = ["sideWidth", "volume", "muted", "hideDockIcon", "animateTray"]
        let existing = defaults.object(forKey: Look.key) != nil
            || oldKeys.contains { defaults.object(forKey: $0) != nil }
            || defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix("NSWindow Frame") }
        if existing {
            // No writes to look or the legacy NSWindow frame on upgrade.
            defaults.set(WindowTemplate.custom.rawValue, forKey: template)
        } else {
            defaults.set(Look.light.rawValue, forKey: Look.key)
            defaults.set(WindowTemplate.vertical.rawValue, forKey: template)
        }
    }
}

/// Shared by the toolbar, keyboard, tray and window probe, even without a
/// visible SwiftUI window. Playback never knows about this object.
@MainActor
final class Presentation: ObservableObject {
    @Published private(set) var template: WindowTemplate
    /// Whether the side menu is out. The one word the toolbar's toggle, the
    /// tray's tick, the keyboard and the split view's own binding all agree
    /// on; the window makes room before it turns true, and the window's own
    /// minimum follows it either way.
    @Published var sideOpen = false {
        didSet {
            guard sideOpen != oldValue else { return }
            if sideOpen { makeRoomForSidebar() }
            refreshContentMinimum()
        }
    }
    @Published var sideWidth: Double {
        didSet { defaults.set(sideWidth, forKey: AppearancePreferences.side) }
    }

    private let defaults: UserDefaults
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var applyingFrame = false
    private var lastSize: NSSize?

    init(defaults: UserDefaults = .standard) {
        AppearancePreferences.prepare(defaults)
        self.defaults = defaults
        template = WindowTemplate(rawValue: defaults.string(forKey: AppearancePreferences.template) ?? "") ?? .custom
        let width = defaults.object(forKey: AppearancePreferences.side) as? Double ?? WindowTemplate.sideRest
        sideWidth = min(WindowTemplate.sideRange.upperBound, max(WindowTemplate.sideRange.lowerBound, width))
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    /// The narrowest the window's contents may be, said out loud: the formal
    /// square while the column is away, and — while it is out — the column at
    /// its own minimum plus the width of the template's own player. The
    /// player beside the column is the player at its template size, never a
    /// squeezed one: 176 + 232 = 408 for the tall card, 176 + 548 = 724 for
    /// the wide one (issue #16: the player must not be narrowed under the
    /// template it belongs to). Custom, which has no template of its own,
    /// keeps the strip it always had. That is the split's arithmetic said in
    /// one number, and it is what leaves an overlay nothing to grow from
    /// (issue #15: the window cannot become narrower than the sidebar plus
    /// the content).
    var contentMinWidth: CGFloat {
        guard sideOpen else { return Metrics.side }
        return Metrics.sideMin + (template.frameSize?.width ?? Metrics.playerMin)
    }

    /// The same number, written on the window itself. SwiftUI writes it from
    /// the view (App.swift); this is the window being told directly, so the
    /// rule holds whichever of the two is heard first.
    private func refreshContentMinimum() {
        window?.contentMinSize = NSSize(width: contentMinWidth, height: Metrics.side)
    }

    /// Before the column comes out: a window too narrow to hold it beside the
    /// player grows to fit both, its left edge kept where it is — the column
    /// slides in beside a player that was never squeezed, and the slide
    /// itself is the split's own motion, not this window's. The growth is put
    /// on the way the templates are: quietly, and never mistaken for a hand's
    /// own resize, which is what Custom is for.
    private func makeRoomForSidebar() {
        guard let window, window.frame.width < contentMinWidth else { return }
        applyingFrame = true
        defer { applyingFrame = false }
        var frame = window.frame
        frame.size.width = contentMinWidth
        window.setFrame(frame, display: true, animate: false)
        lastSize = window.frame.size
    }

    func select(_ wanted: WindowTemplate) {
        guard wanted != .custom else { return }
        template = wanted
        defaults.set(wanted.rawValue, forKey: AppearancePreferences.template)
        sideOpen = false
        sideWidth = WindowTemplate.sideRest
        if let window, let size = wanted.frameSize { resize(window, to: size) }
    }

    func attach(_ window: NSWindow) {
        guard self.window !== window else { return }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        self.window = window
        // Called after SwiftUI has installed the toolbar and restored its frame.
        if let size = template.frameSize {
            resize(window, to: size)
        } else if let saved = defaults.string(forKey: AppearancePreferences.frame) {
            applyingFrame = true
            window.setFrame(NSRectFromString(saved), display: true)
            applyingFrame = false
        }
        lastSize = window.frame.size
        refreshContentMinimum()
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.frameChanged() }
            })
        }
    }

    private func resize(_ window: NSWindow, to size: NSSize) {
        // The system does the arithmetic: the template's frame size is put
        // through the window's own frame-to-content conversion, `setContentSize`
        // puts it on, and the top-left corner is put back where the hand left
        // it. No intermediate animated frames, no accidental Custom, and no
        // motion even with Reduce Motion.
        applyingFrame = true
        defer { applyingFrame = false }
        let top = window.frame.maxY
        let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: size)).size
        window.setContentSize(content)
        if window.frame.maxY != top {
            window.setFrameTopLeftPoint(NSPoint(x: window.frame.minX, y: top))
        }
        lastSize = window.frame.size
    }

    private func frameChanged() {
        guard let window, !applyingFrame else { return }
        if let lastSize, lastSize != window.frame.size {
            template = .custom
            defaults.set(WindowTemplate.custom.rawValue, forKey: AppearancePreferences.template)
        }
        lastSize = window.frame.size
        if template == .custom {
            defaults.set(NSStringFromRect(window.frame), forKey: AppearancePreferences.frame)
        }
    }
}
