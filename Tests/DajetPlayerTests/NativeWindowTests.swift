import AppKit
import XCTest
@testable import DajetPlayer

// The window's own rules after the split view arrived (issue #15): the
// minimum that keeps the column beside the player rather than over it, the
// room the window makes before the column comes out, and the templates still
// being the templates through the system's own resize.
//
// Everything here is said on a plain NSWindow, the way PresentationTests says
// it: the window is the app's, the model is the app's, and none of it needs a
// SwiftUI scene to be true.

@MainActor
final class NativeWindowTests: XCTestCase {

    // MARK: - the fixtures

    private func defaults() -> (UserDefaults, String) {
        let name = "ru.dajet.player.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    private func makeWindow(width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 76, y: 74, width: width, height: height),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }

    // MARK: - the minimum that keeps the column beside the player

    /// The split's arithmetic said out loud: the formal square while the
    /// column is away, and — while it is out — the column at its own minimum
    /// plus the width of the template's own player: 408 for the tall card,
    /// 724 for the wide one, the player never squeezed under its template
    /// (issue #16). Custom, which has no template, keeps the strip it had.
    func testContentMinimumMatrix() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        let model = Presentation(defaults: store)
        XCTAssertFalse(model.sideOpen)
        XCTAssertEqual(model.contentMinWidth, Metrics.side,
                       "with the column away, the window's floor is the formal square")

        model.sideOpen = true
        XCTAssertEqual(model.contentMinWidth, 408,
                       "the tall card beside the column: the column plus the template's own 232")
        XCTAssertEqual(model.contentMinWidth,
                       Metrics.sideMin + WindowTemplate.vertical.frameSize!.width,
                       "said the same through the template's own width")

        model.select(.horizontal)
        XCTAssertFalse(model.sideOpen, "a template switch closes the column")
        model.sideOpen = true
        XCTAssertEqual(model.contentMinWidth, 724,
                       "the wide card beside the column: the column plus the template's own 548")
        XCTAssertEqual(model.contentMinWidth,
                       Metrics.sideMin + WindowTemplate.horizontal.frameSize!.width,
                       "said the same through the template's own width")
    }

    // MARK: - the room made before the column arrives

    /// Opening the column in a window too narrow for both widens the window
    /// itself, its left edge kept where it is, and the window's own minimum
    /// moves with the state — which is what leaves an overlay nothing to grow
    /// from, on the window itself and not merely in the layout.
    func testSidebarMakesRoomInTheWindowItself() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        let model = Presentation(defaults: store)
        model.select(.vertical)

        let player = makeWindow(width: 232, height: 389)
        defer { player.close() }
        model.attach(player)

        XCTAssertEqual(player.frame.size, WindowTemplate.vertical.frameSize!)
        XCTAssertEqual(player.contentMinSize.width, Metrics.side,
                       "the window is told the minimum directly, not only through the view")
        let left = player.frame.minX

        model.sideOpen = true
        XCTAssertGreaterThanOrEqual(player.frame.width, model.contentMinWidth,
                                    "the window holds column and player before the column arrives")
        XCTAssertEqual(player.frame.minX, left,
                       "the window grows where the column is not")
        XCTAssertEqual(player.contentMinSize.width, model.contentMinWidth)

        model.sideOpen = false
        XCTAssertEqual(player.contentMinSize.width, Metrics.side,
                       "with the column away, the formal square is the floor again")
    }

    // MARK: - the templates, through the system's own resize

    /// A template resize is the system's own conversion — the template's
    /// frame size goes in through the window's frame-to-content arithmetic
    /// and `setContentSize` puts it on — and the top-left corner stays where
    /// the hand left it. The same walk the older frame test makes, said once
    /// through the new plumbing.
    func testTemplateResizeGoesThroughTheSystemsOwnConversion() {
        let (store, name) = defaults()
        defer { store.removePersistentDomain(forName: name) }
        let model = Presentation(defaults: store)

        let player = makeWindow(width: 560, height: 420)
        defer { player.close() }
        let top = player.frame.maxY

        model.attach(player)
        XCTAssertEqual(player.frame.size, WindowTemplate.vertical.frameSize!)
        XCTAssertEqual(player.frame.maxY, top, "the top-left corner does not move")

        model.select(.horizontal)
        XCTAssertEqual(player.frame.size, WindowTemplate.horizontal.frameSize!)
        XCTAssertEqual(player.frame.maxY, top)
        XCTAssertEqual(model.template, .horizontal,
                       "the system's own resize is not mistaken for a hand's")
    }

    /// The numbers the split is told, in one place: the templates' own range
    /// and resting width for the column, and Custom's own floor for the
    /// player — the templates need none of that kind, their players keeping
    /// the template's own width beside the column (issue #16). The divider
    /// holds the column in the range; the window's minimum holds the rest.
    func testTheNumbersTheSplitIsTold() {
        XCTAssertEqual(WindowTemplate.sideRange, 176.0...240.0)
        XCTAssertEqual(WindowTemplate.sideRest, 200)
        XCTAssertEqual(Metrics.sideMin, 176)
        XCTAssertEqual(Metrics.sideMax, 440)
        XCTAssertEqual(Metrics.playerMin, 200,
                       "Custom's floor — the one template-less width")
        XCTAssertEqual(Metrics.scrubStrip, 16,
                       "the strip a hand and the keyboard land on is at least sixteen points")
        XCTAssertEqual(WindowTemplate.toolbarChrome, 52)
    }
}
