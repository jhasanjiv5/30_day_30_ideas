// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ErgoPods",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "ErgoPods", targets: ["ErgoPods"])
    ],
    targets: [
        .target(
            name: "ErgoPods",
            path: "ErgoPods"
        )
    ]
)
