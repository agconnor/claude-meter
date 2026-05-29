// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeMeter",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic: parsing, formatting, models. No AppKit / Keychain / network.
        // Kept dependency-free so it is fast and deterministic to unit test.
        .target(
            name: "ClaudeMeterCore",
            path: "Sources/ClaudeMeterCore"
        ),
        // The menu-bar agent itself (AppKit + Keychain + URLSession).
        .executableTarget(
            name: "ClaudeMeter",
            dependencies: ["ClaudeMeterCore"],
            path: "Sources/ClaudeMeter"
        ),
        .testTarget(
            name: "ClaudeMeterCoreTests",
            dependencies: ["ClaudeMeterCore"],
            path: "Tests/ClaudeMeterCoreTests"
        ),
    ]
)
