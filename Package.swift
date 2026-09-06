// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArtazzenMobile",
    // macOS 14 is the Observation minimum for ArtazzenCore, not macOS app support.
    // Build the iOS-only executable with xcodebuild and an explicit iOS destination.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ArtazzenCore", targets: ["ArtazzenCore"]),
        .executable(name: "ArtazzenMobile", targets: ["ArtazzenMobile"]),
    ],
    targets: [
        .target(name: "ArtazzenCore", path: "Sources/Core"),
        .executableTarget(name: "ArtazzenMobile", dependencies: ["ArtazzenCore"], path: "Sources", exclude: ["Core"]),
        .testTarget(name: "ArtazzenMobileTests", dependencies: ["ArtazzenCore"], path: "Tests/ArtazzenMobileTests"),
    ]
)
