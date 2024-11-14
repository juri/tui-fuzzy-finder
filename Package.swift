// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tui-fuzzy-finder",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "sfzf", targets: ["CLI"]),
        .library(name: "FuzzyTUI", targets: ["FuzzyTUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FuzzyTUI",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: [
                .target(name: "FuzzyTUI")
            ]
        ),
    ]
)
