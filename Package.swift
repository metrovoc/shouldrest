// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ShouldRest",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ShouldRestCore",
            targets: ["ShouldRestCore"]
        ),
        .executable(
            name: "shouldrest",
            targets: ["shouldrest"]
        )
    ],
    targets: [
        .target(
            name: "ShouldRestCore"
        ),
        .executableTarget(
            name: "shouldrest",
            dependencies: ["ShouldRestCore"],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "ShouldRestCoreTests",
            dependencies: ["ShouldRestCore"]
        ),
        .testTarget(
            name: "ShouldRestAppTests",
            dependencies: ["shouldrest"]
        )
    ]
)
