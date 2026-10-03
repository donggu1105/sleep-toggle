// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SleepToggle",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SleepToggle", targets: ["SleepToggle"])],
    targets: [
        .target(name: "SleepToggleCore"),
        .executableTarget(name: "SleepToggle", dependencies: ["SleepToggleCore"]),
        .testTarget(name: "SleepToggleCoreTests", dependencies: ["SleepToggleCore"]),
    ]
)
