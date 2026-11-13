// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "FieldTwin",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .iOSApplication(
            name: "FieldTwin",
            targets: ["AppModule"],
            bundleIdentifier: "dev.fieldtwin.spatialmcp",
            teamIdentifier: "",
            displayVersion: "1.0.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .compass),
            accentColor: .presetColor(.cyan),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft
            ],
            capabilities: [
                .camera(purposeString: "Scans physical equipment and reads LiDAR depth frames for the 3D semantic twin."),
                .microphone(purposeString: "Captures ambient voice intents and acoustic fault signatures locally on-device."),
                .nearbyInteractionAllowOnce(purposeString: "Syncs UWB spatial distance and bearing between iPad Pro and iPhone companion."),
                .localNetwork(purposeString: "Communicates offline with local Spatial-MCP device bridges over Bonjour.", bonjourServices: ["_fieldtwin-mcp._tcp"])
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "Sources"
        )
    ]
)
