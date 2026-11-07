// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FastShopper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FastShopper", targets: ["FastShopper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FastShopper",
            dependencies: [],
            path: "Sources/FastShopper"
        )
    ]
)
