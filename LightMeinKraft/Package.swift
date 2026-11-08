// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LightMeinKraft",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LightMeinKraft",
            targets: ["LightMeinKraft"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LightMeinKraft",
            path: "Sources/LightMeinKraft"
        ),
        .testTarget(
            name: "LightMeinKraftTests",
            dependencies: ["LightMeinKraft"],
            path: "Tests/LightMeinKraftTests"
        )
    ]
)
