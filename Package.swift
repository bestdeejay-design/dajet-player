// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DajetPlayer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DajetPlayer",
            path: "Sources/DajetPlayer",
            // Same reasoning as the browser next door: the whole interface is
            // main-thread by nature, and Swift 6's strict isolation buys
            // nothing here but ceremony.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
