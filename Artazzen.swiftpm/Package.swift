// swift-tools-version: 5.9
import AppleProductTypes
import PackageDescription

let package = Package(
    name: "Artazzen",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "Artazzen",
            targets: ["AppModule"],
            bundleIdentifier: "com.artazzen.mobile",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .cloud),
            accentColor: .presetColor(.teal),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
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
