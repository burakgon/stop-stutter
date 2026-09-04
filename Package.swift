// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StopStutter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "StopStutter", targets: ["StopStutter"]),
        .executable(name: "StopStutterHelper", targets: ["StopStutterHelper"])
    ],
    targets: [
        .target(name: "StopStutterCore"),
        .executableTarget(name: "StopStutter", dependencies: ["StopStutterCore"]),
        .executableTarget(name: "StopStutterHelper", dependencies: ["StopStutterCore"]),
        .testTarget(name: "StopStutterCoreTests", dependencies: ["StopStutterCore"])
    ],
    swiftLanguageModes: [.v5]
)
