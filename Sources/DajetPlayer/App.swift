import SwiftUI

// A window, and nothing in it yet. This is the skeleton: it builds, it opens,
// and it sits there quietly. Playback arrives in the next wave; the two skins
// after that. No toolbar, no sidebar, no title bar.

@main
struct DajetPlayerApp: App {
    var body: some Scene {
        Window("Dajet Player", id: "player") {
            // Empty on purpose. Something to hold the window's size, and
            // nothing to look at.
            Color.clear
                .frame(minWidth: 520, minHeight: 320)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 560)
    }
}
