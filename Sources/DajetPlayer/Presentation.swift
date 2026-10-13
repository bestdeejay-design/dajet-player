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

    static var initialContentSize: NSSize {
        let remembered = WindowTemplate(rawValue: UserDefaults.standard.string(forKey: AppearancePreferences.template) ?? "")
        guard let frame = remembered?.frameSize else { return NSSize(width: 560, height: 420) }
        return NSSize(width: frame.width, height: frame.height - 52)
    }

    // Local to the templates; the old dynamic window keeps Metrics.side*.
    static let sideRest = 200.0
    static let sideRange = 176.0...240.0
}

enum AppearancePreset: String, CaseIterable {
    case aero, obsidian, system

    var title: String { rawValue.capitalized }
    var theme: Theme {
        switch self {
        case .aero: return .light
        case .obsidian: return .dark
        case .system: return .system
        }
    }

    /// Re-selecting a theme must not undo an explicit Window > Horizontal.
    /// A different appearance, or Custom geometry, does restore its default.
    func resetsTemplate(current: AppearancePreset?, template: WindowTemplate) -> Bool {
        current != self || template == .custom
    }
}

enum AppearancePreferences {
    static let template = "windowTemplate"
    static let preset = "appearancePreset"
    static let frame = "customWindowFrame"
    static let side = "templateSideWidth"

    /// Standard defaults are ru.dajet.player in the app bundle, beside `look`.
    /// Do not register defaults before checking: that would hide an upgrade.
    static func prepare(_ defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: template) == nil,
              defaults.object(forKey: preset) == nil else { return }
        let oldKeys = [Theme.key, "sideWidth", "volume", "muted", "hideDockIcon", "animateTray"]
        let existing = oldKeys.contains { defaults.object(forKey: $0) != nil }
            || defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix("NSWindow Frame") }
        if existing {
            // No writes to look or the legacy NSWindow frame on upgrade.
            defaults.set(WindowTemplate.custom.rawValue, forKey: template)
        } else {
            defaults.set(AppearancePreset.aero.rawValue, forKey: preset)
            defaults.set(Theme.light.rawValue, forKey: Theme.key)
            defaults.set(WindowTemplate.vertical.rawValue, forKey: template)
        }
    }
}

/// Shared by the toolbar, keyboard, tray and window probe, even without a
/// visible SwiftUI window. Playback never knows about this object.
@MainActor
final class Presentation: ObservableObject {
    @Published private(set) var template: WindowTemplate
    @Published private(set) var preset: AppearancePreset?
    @Published var sideOpen = false
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
        preset = AppearancePreset(rawValue: defaults.string(forKey: AppearancePreferences.preset) ?? "")
        let width = defaults.object(forKey: AppearancePreferences.side) as? Double ?? WindowTemplate.sideRest
        sideWidth = min(WindowTemplate.sideRange.upperBound, max(WindowTemplate.sideRange.lowerBound, width))
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func select(_ wanted: WindowTemplate) {
        guard wanted != .custom else { return }
        template = wanted
        defaults.set(wanted.rawValue, forKey: AppearancePreferences.template)
        sideOpen = false
        sideWidth = WindowTemplate.sideRest
        if let window, let size = wanted.frameSize { resize(window, to: size) }
    }

    func select(_ wanted: AppearancePreset) {
        let reset = wanted.resetsTemplate(current: preset, template: template)
        preset = wanted
        defaults.set(wanted.rawValue, forKey: AppearancePreferences.preset)
        defaults.set(wanted.theme.rawValue, forKey: Theme.key)
        wanted.theme.apply()
        if reset { select(.vertical) }
    }

    /// A theme-only toolbar change remains theme-only; it cannot leave a
    /// misleading checkmark beside an appearance it no longer matches.
    func themeChanged(_ theme: Theme) {
        guard preset?.theme != theme else { return }
        preset = nil
        defaults.removeObject(forKey: AppearancePreferences.preset)
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
        for name in [NSWindow.didResizeNotification, NSWindow.didMoveNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.frameChanged() }
            })
        }
    }

    private func resize(_ window: NSWindow, to size: NSSize) {
        // Preserve the top-left, not the bottom-left; no intermediate animated
        // frames, no accidental Custom, and no motion even with Reduce Motion.
        applyingFrame = true
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true, animate: false)
        lastSize = window.frame.size
        applyingFrame = false
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
