// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DaybreakEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DaybreakEngine", targets: ["DaybreakEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.20.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "0.20.0"),
    ],
    targets: [
        .target(
            name: "DaybreakEngine",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
            ]
        ),
    ]
)
