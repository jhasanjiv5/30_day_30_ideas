// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpatialRoomAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpatialRoomAI",
            targets: ["SpatialRoomAI"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SpatialRoomAI",
            dependencies: [],
            path: "Sources"
        ),
    ]
)
