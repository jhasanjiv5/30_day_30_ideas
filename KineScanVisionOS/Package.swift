// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KineScanVisionOS",
    defaultLocalization: "en",
    platforms: [
        .visionOS(.v2)
    ],
    products: [
        .executable(
            name: "KineScanVisionOS",
            targets: ["KineScanVisionOS"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "KineScanVisionOS",
            dependencies: [],
            path: "Sources"
        )
    ]
)
