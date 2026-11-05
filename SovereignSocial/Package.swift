// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SovereignSocial",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SovereignSocialApp",
            targets: ["SovereignSocialApp"]
        ),
        .library(
            name: "SovereignSocial",
            targets: ["SovereignSocial"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SovereignSocial",
            dependencies: [],
            path: "Sources/SovereignSocial"
        ),
        .executableTarget(
            name: "SovereignSocialApp",
            dependencies: ["SovereignSocial"],
            path: "Sources/SovereignSocialApp"
        ),
        .testTarget(
            name: "SovereignSocialTests",
            dependencies: ["SovereignSocial"],
            path: "Tests/SovereignSocialTests"
        ),
    ]
)
