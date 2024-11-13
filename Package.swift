// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoroSwift",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LoroSwift",
            targets: ["LoroSwift"]
        ),
    ],
    targets: [
        // Define a "LoroSwiftBuildPlugin" that helps us manage build sequencing like the "RVRegistrationPlugin" does for our RVRegistrationClient package.
        .plugin(
            name: "LoroSwiftBuildPlugin",
            capability: .buildTool
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LoroSwift",
            plugins: [
                "LoroSwiftBuildPlugin"
            ]
        ),
        .testTarget(
            name: "LoroSwiftTests",
            dependencies: ["LoroSwift"]
        )
    ]
)
