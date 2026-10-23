// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DajetPlayer",
    platforms: [.macOS(.v14)],
    dependencies: [
        // The series' own design layer — palette, metrics, springs, the door —
        // in the package next door (stage 4: the player is the first of the
        // line to sit on it). The player's local duplicates of it are gone
        // from Design.swift, which opens the package to the whole target.
        .package(path: "../ui")
    ],
    targets: [
        .executableTarget(
            name: "DajetPlayer",
            dependencies: [.product(name: "DajetUI", package: "ui")],
            path: "Sources/DajetPlayer",
            // Same reasoning as the browser next door: the whole interface is
            // main-thread by nature, and Swift 6's strict isolation buys
            // nothing here but ceremony.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DajetPlayerTests",
            dependencies: ["DajetPlayer"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
