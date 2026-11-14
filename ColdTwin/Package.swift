// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ColdTwin",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "ColdTwinCore", targets: ["ColdTwinCore"]),
        .executable(name: "ColdTwinApp", targets: ["ColdTwinApp"])
    ],
    targets: [
        .target(
            name: "ColdTwinCore",
            dependencies: []
        ),
        .executableTarget(
            name: "ColdTwinApp",
            dependencies: ["ColdTwinCore"]
        ),
        .testTarget(
            name: "ColdTwinCoreTests",
            dependencies: ["ColdTwinCore"]
        )
    ]
)
