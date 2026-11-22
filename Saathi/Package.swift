// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaathiCore",
    defaultLocalization: "en-IN",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SaathiCore",
            targets: ["SaathiCore"]
        )
    ],
    targets: [
        .target(
            name: "SaathiCore",
            path: "Packages/SaathiCore/Sources/SaathiCore"
        ),
        .testTarget(
            name: "SaathiCoreTests",
            dependencies: ["SaathiCore"],
            path: "Tests/SaathiCoreTests"
        ),
        .testTarget(
            name: "SaathiPrivacyTests",
            dependencies: ["SaathiCore"],
            path: "Tests/SaathiPrivacyTests"
        )
    ]
)
