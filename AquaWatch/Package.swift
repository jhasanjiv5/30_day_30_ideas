// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AquaWatch",
    platforms: [
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "AquaWatchApp",
            targets: ["AquaWatchApp"]
        ),
    ],
    targets: [
        .target(
            name: "AquaWatchApp",
            path: "AquaWatch"
        ),
    ]
)