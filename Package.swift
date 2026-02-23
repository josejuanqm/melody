// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Melody",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Runtime", targets: ["Runtime"]),
        .executable(name: "melody", targets: ["MelodyCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.3"),
    ],
    targets: [
        // Lua 5.4 C library (vendored)
        .target(
            name: "CLua",
            path: "Sources/CLua",
            publicHeadersPath: "include",
            cSettings: [
                .define("LUA_USE_POSIX", .when(platforms: [.macOS, .linux])),
                .define("LUA_USE_IOS", .when(platforms: [.iOS, .tvOS, .visionOS])),
                .headerSearchPath("."),
            ]
        ),

        // Core types shared between CLI and Runtime
        .target(
            name: "Core",
            dependencies: ["Yams"],
            path: "Sources/Core"
        ),

        .target(
            name: "Runtime",
            dependencies: ["Core", "CLua"],
            path: "Sources/Runtime",
            swiftSettings: [
                .define("MELODY_DEV", .when(configuration: .debug)),
            ]
        ),

        // CLI executable
        .executableTarget(
            name: "MelodyCLI",
            dependencies: [
                "Core",
                "Runtime",
                "Yams",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CLI",
            resources: [.copy("Resources")],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),

        // Tests
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests",
            resources: [.copy("Fixtures")]
        ),

        .testTarget(
            name: "RuntimeTests",
            dependencies: ["Runtime"],
            path: "Tests/RuntimeTests"
        ),

    ]
)
