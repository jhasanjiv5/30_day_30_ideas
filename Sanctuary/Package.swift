// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sanctuary",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Sanctuary",
            targets: ["Sanctuary"]
        ),
    ],
    dependencies: [
        // MLX Swift for on-device Foundation Model inference on Apple Silicon
        // .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main")
    ],
    targets: [
        .target(
            name: "Sanctuary",
            path: "Sanctuary",
            resources: []
        ),
    ]
)
