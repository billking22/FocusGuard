// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FocusGuard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FocusGuard", targets: ["FocusGuard"])
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "FocusGuard",
            dependencies: [.product(name: "SQLite", package: "SQLite.swift")],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Vision"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
