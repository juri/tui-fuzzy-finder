// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tui-fuzzy-finder",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "sfzf", targets: ["FuzzyFinderCLI"]),
        .library(name: "FuzzyTUI", targets: ["FuzzyTUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(
            url: "https://github.com/swift-server/swift-service-lifecycle.git",
            from: "2.6.3"
        ),
        .package(url: "https://github.com/juri/terminal-ansi", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "FuzzyTUI",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "UnixSignals", package: "swift-service-lifecycle"),
                .product(name: "TerminalANSI", package: "terminal-ansi"),
            ]
        ),
        .testTarget(
            name: "FuzzyTUITests",
            dependencies: [
                .target(name: "FuzzyTUI")
            ]
        ),
        .executableTarget(
            name: "FuzzyFinderCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "FuzzyTUI"),
            ]
        ),
    ]
)
