// swift-tools-version: 6.2
import PackageDescription

// RideOrNah's business logic. Kept free of UIKit and SwiftUI so it builds and tests on macOS
// with `swift test`. No dependencies: the app ships Apple frameworks only.
let package = Package(
    name: "RideOrNahKit",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SharedContainer", targets: ["SharedContainer"]),
        .library(name: "VerdictEngine", targets: ["VerdictEngine"]),
    ],
    targets: [
        .target(name: "SharedContainer"),
        .testTarget(name: "SharedContainerTests", dependencies: ["SharedContainer"]),
        .target(name: "VerdictEngine"),
        .testTarget(name: "VerdictEngineTests", dependencies: ["VerdictEngine"]),
    ]
)
