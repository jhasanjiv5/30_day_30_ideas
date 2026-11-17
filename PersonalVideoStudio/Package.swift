// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PersonalVideoStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PersonalVideoStudioCore",
            targets: ["PersonalVideoStudioCore"]
        ),
        .library(
            name: "PersonalVideoStudioUI",
            targets: ["PersonalVideoStudioUI"]
        ),
        .executable(
            name: "PersonalVideoStudioApp",
            targets: ["PersonalVideoStudioApp"]
        )
    ],
    dependencies: [
        // Zero mandatory external package dependencies for the MVP.
        // Rendering, composition, audio inspection, and local persistence rely strictly
        // on native Apple macOS frameworks (AVFoundation, CoreImage, CoreGraphics, AppKit, SwiftUI).
    ],
    targets: [
        .target(
            name: "PersonalVideoStudioCore",
            dependencies: [],
            path: "Sources/PersonalVideoStudioCore"
        ),
        .target(
            name: "PersonalVideoStudioUI",
            dependencies: ["PersonalVideoStudioCore"],
            path: "Sources/PersonalVideoStudioUI"
        ),
        .executableTarget(
            name: "PersonalVideoStudioApp",
            dependencies: [
                "PersonalVideoStudioCore",
                "PersonalVideoStudioUI"
            ],
            path: "App",
            exclude: [
                "Assets.xcassets",
                "Info.plist",
                "PersonalVideoStudio.entitlements"
            ]
        ),
        .testTarget(
            name: "PersonalVideoStudioCoreTests",
            dependencies: ["PersonalVideoStudioCore"],
            path: "Tests/PersonalVideoStudioCoreTests"
        )
    ]
)
