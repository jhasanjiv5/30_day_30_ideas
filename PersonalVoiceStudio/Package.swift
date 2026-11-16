// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PersonalVoiceStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PersonalVoiceStudioCore",
            targets: ["PersonalVoiceStudioCore"]
        ),
        .library(
            name: "PersonalVoiceStudioUI",
            targets: ["PersonalVoiceStudioUI"]
        )
    ],
    dependencies: [
        // Optional on-device Apple Silicon inference package (MIT License):
        // Uncomment in Xcode / SwiftPM when building on Apple Silicon macOS with MLX:
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "PersonalVoiceStudioCore",
            dependencies: [
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
            ],
            path: "Sources/PersonalVoiceStudioCore"
        ),
        .target(
            name: "PersonalVoiceStudioUI",
            dependencies: ["PersonalVoiceStudioCore"],
            path: "Sources/PersonalVoiceStudioUI"
        ),
        .testTarget(
            name: "PersonalVoiceStudioCoreTests",
            dependencies: ["PersonalVoiceStudioCore"],
            path: "Tests/PersonalVoiceStudioCoreTests"
        )
    ]
)
