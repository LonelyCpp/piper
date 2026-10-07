// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Piper",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Piper",
            path: "Sources/Piper",
            swiftSettings: [
                // Phase 0 decision — see docs/DECISIONS.md ADR-0002.
                // Revisit when AppKit timer/notification plumbing lands.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
