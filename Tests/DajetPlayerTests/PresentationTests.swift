import AppKit
import XCTest
@testable import DajetPlayer

final class PresentationTests: XCTestCase {
    private func defaults() -> (UserDefaults, String) {
        let name = "ru.dajet.player.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testCleanInstallIsLightVerticalAndMigrationIsIdempotent() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        AppearancePreferences.prepare(store)
        XCTAssertEqual(store.string(forKey: Look.key), "light")
        XCTAssertNil(store.object(forKey: AppearancePreferences.preset))
        XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "vertical")
        store.set("horizontal", forKey: AppearancePreferences.template)
        AppearancePreferences.prepare(store)
        XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "horizontal")
        XCTAssertEqual(store.string(forKey: Look.key), "light")
    }

    func testLegacyLookAndFrameAreUntouched() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        store.set("dark", forKey: Look.key)
        store.set("76 74 620 458", forKey: "NSWindow Frame player")
        store.set(249.02, forKey: "sideWidth")
        AppearancePreferences.prepare(store)
        XCTAssertEqual(store.string(forKey: Look.key), "dark")
        XCTAssertEqual(store.string(forKey: "NSWindow Frame player"), "76 74 620 458")
        XCTAssertEqual(store.double(forKey: "sideWidth"), 249.02)
        XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "custom")
        XCTAssertNil(store.object(forKey: AppearancePreferences.preset))
    }

    func testLegacySystemWithoutLookIsNotMistakenForFreshInstall() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        store.set(0.5, forKey: "volume")
        AppearancePreferences.prepare(store)
        XCTAssertNil(store.object(forKey: Look.key))
        XCTAssertNil(store.object(forKey: AppearancePreferences.preset))
        XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "custom")
    }

    func testLegacyPresetBecomesLookAndKeyLeaves() {
        let cases = ["aero": "light", "obsidian": "dark", "system": "system"]
        for (preset, look) in cases {
            let (store, name) = defaults()
            defer { store.removePersistentDomain(forName: name) }
            store.set(preset, forKey: AppearancePreferences.preset)
            AppearancePreferences.prepare(store)
            XCTAssertEqual(store.string(forKey: Look.key), look)
            XCTAssertNil(store.object(forKey: AppearancePreferences.preset), "ключ пресета удалён")
        }
        // Явный look не перезаписывается пресетом.
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        store.set("obsidian", forKey: AppearancePreferences.preset)
        store.set("light", forKey: Look.key)
        AppearancePreferences.prepare(store)
        XCTAssertEqual(store.string(forKey: Look.key), "light")
    }

    func testThemeChangeKeepsTemplate() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        AppearancePreferences.prepare(store)
        store.set("horizontal", forKey: AppearancePreferences.template)
        store.set("dark", forKey: Look.key)
        XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "horizontal",
                       "Смена темы — не сменa шаблона")
    }

    func testTemplatesHaveOnlyOwnersFrameSizes() {
        XCTAssertEqual(WindowTemplate.horizontal.frameSize, NSSize(width: 548, height: 284))
        XCTAssertEqual(WindowTemplate.vertical.frameSize, NSSize(width: 232, height: 441))
        XCTAssertNil(WindowTemplate.custom.frameSize)
        XCTAssertEqual(WindowTemplate.sideRange, 176...240)
        XCTAssertEqual(WindowTemplate.sideRest, 200)
        XCTAssertEqual(Metrics.side, 232)
        XCTAssertEqual(Metrics.sideMax, 440)
    }

    func testSelectionPersistenceAndSharedColumn() async {
        await MainActor.run {
            _ = NSApplication.shared
            let (store, name) = defaults()
            defer { store.removePersistentDomain(forName: name) }
            let model = Presentation(defaults: store)
            XCTAssertFalse(model.sideOpen)
            model.sideOpen = true
            model.select(WindowTemplate.horizontal)
            XCTAssertFalse(model.sideOpen)
            store.set("light", forKey: Look.key)
            XCTAssertEqual(model.template, .horizontal, "A look change preserves the chosen template")
            store.set("dark", forKey: Look.key)
            XCTAssertEqual(model.template, .horizontal)
            model.sideWidth = 220
            let restored = Presentation(defaults: store)
            XCTAssertEqual(restored.template, .horizontal)
            XCTAssertEqual(store.string(forKey: Look.key), "dark")
            XCTAssertEqual(restored.sideWidth, 220)
        }
    }

    func testFrameApplicationManualResizeAndReopen() async {
        await MainActor.run {
            _ = NSApplication.shared
            let (store, name) = defaults()
            defer { store.removePersistentDomain(forName: name) }
            let model = Presentation(defaults: store)
            let window = NSWindow(contentRect: NSRect(x: 76, y: 74, width: 560, height: 420),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let top = window.frame.maxY
            model.attach(window)
            XCTAssertEqual(window.frame.size, WindowTemplate.vertical.frameSize!)
            XCTAssertEqual(window.frame.maxY, top)
            model.select(WindowTemplate.horizontal)
            XCTAssertEqual(window.frame.size, WindowTemplate.horizontal.frameSize!)
            XCTAssertEqual(model.template, .horizontal, "Programmatic resize must not become Custom")
            window.setFrameOrigin(NSPoint(x: 100, y: 100))
            XCTAssertEqual(model.template, .horizontal, "Moving is not resizing")
            var custom = window.frame
            custom.size.width += 20
            window.setFrame(custom, display: false)
            XCTAssertEqual(model.template, .custom)
            XCTAssertEqual(store.string(forKey: AppearancePreferences.template), "custom")
            // Going back to exactly a template size by hand still is Custom.
            custom.size = WindowTemplate.horizontal.frameSize!
            window.setFrame(custom, display: false)
            XCTAssertEqual(model.template, .custom)
            let restored = Presentation(defaults: store)
            let reopened = NSWindow(contentRect: .zero, styleMask: [.titled, .resizable],
                                    backing: .buffered, defer: false)
            reopened.isReleasedWhenClosed = false
            defer { reopened.close() }
            restored.attach(reopened)
            XCTAssertEqual(reopened.frame, window.frame)
            store.set("light", forKey: Look.key)
            XCTAssertEqual(model.template, .custom, "A look change leaves Custom alone")
        }
    }
}
