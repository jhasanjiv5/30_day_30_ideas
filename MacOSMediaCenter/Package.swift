// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacOSMediaCenter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacOSMediaCenter", targets: ["MacOSMediaCenter"])
    ],
    targets: [
        .executableTarget(
            name: "MacOSMediaCenter",
            path: "MacOSMediaCenter",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "MacOSMediaCenterTests",
            dependencies: ["MacOSMediaCenter"],
            path: "Tests"
        )
    ]
)
