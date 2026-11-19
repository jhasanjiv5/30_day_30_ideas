// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EnsembleCore",
    platforms: [
        .iOS("26.0"),
        .tvOS("26.0"),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EnsembleCore",
            targets: ["EnsembleCore"]
        )
    ],
    targets: [
        .target(
            name: "EnsembleCore",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EnsembleCoreTests",
            dependencies: ["EnsembleCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
