// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoroSwift",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Foreign Function Interface to Loro's Rust implementation, that provides the loroFFI.h C header that Swift imports declarations from
        .library(
            name: "loroFFI",
            targets: ["loroFFI"]
        ),
        // Swift code built atop the loroFFI API
        .library(
            name: "LoroSwift",
            targets: ["LoroSwift"]
        )
    ],
    targets: [
        .target(
            name: "loroFFI"
        ),
        .target(
            name: "LoroSwift",
            dependencies: ["loroFFI"],
            path: "Sources/Loro"
        ),
    ]
)
