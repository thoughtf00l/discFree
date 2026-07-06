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
        .library(name: "DiscFreeCore", targets: ["DiscFreeCore"])
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
        )
    ]
)
