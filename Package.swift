// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Swaype",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwaypeCore", targets: ["SwaypeCore"]),
        .executable(name: "Swaype", targets: ["Swaype"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SwaypeCore",
            path: "Sources/SwaypeCore"
        ),
        .executableTarget(
            name: "Swaype",
            dependencies: [
                "SwaypeCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/Swaype"
        ),
        .testTarget(
            name: "SwaypeCoreTests",
            dependencies: ["SwaypeCore"],
            path: "Tests/SwaypeCoreTests"
        )
    ]
)
