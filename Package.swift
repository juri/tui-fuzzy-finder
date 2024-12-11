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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(
            url: "https://github.com/swift-server/swift-service-lifecycle.git",
            revision: "a6a4bc71ccfa2fd4e33ca247855df139d904d51f"
        ),
    ],
    targets: [
        .target(
            name: "FuzzyTUI",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "UnixSignals", package: "swift-service-lifecycle"),
            ]
        ),
        .testTarget(
            name: "FuzzyTUITests",
            dependencies: [
                .target(name: "FuzzyTUI")
            ]
        ),
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "FuzzyTUI"),
            ]
        ),
    ]
)
