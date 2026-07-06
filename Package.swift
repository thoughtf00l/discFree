// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiscFreeCore",
    // macOS 15: ScanCoordinator relies on Synchronization's Atomic/Mutex, which are macOS 15+,
    // and the app itself deploys to 15.0.
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "DiscFreeCore", targets: ["DiscFreeCore"]),
        .executable(name: "discfree", targets: ["discfree"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "DiscFreeCore",
            // Match the app's SWIFT_VERSION (5.0); the moved code is written for the Swift 5
            // language mode and is not being migrated to Swift 6 strict concurrency here.
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "DiscFreeCoreTests",
            dependencies: ["DiscFreeCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // All command logic lives here so it can be unit-tested without spawning a process.
        .target(
            name: "DiscFreeCLI",
            dependencies: [
                "DiscFreeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Thin entry point: parses arguments and dispatches into DiscFreeCLI.
        .executableTarget(
            name: "discfree",
            dependencies: ["DiscFreeCLI"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "DiscFreeCLITests",
            dependencies: ["DiscFreeCLI", "DiscFreeCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
