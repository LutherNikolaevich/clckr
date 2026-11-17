// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AutoClicker",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AutoClickerCore"),
        .executableTarget(name: "AutoClicker", dependencies: ["AutoClickerCore"]),
        .testTarget(name: "AutoClickerCoreTests", dependencies: ["AutoClickerCore"]),
    ]
)
