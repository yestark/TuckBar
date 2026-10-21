// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TuckBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TuckBar", targets: ["TuckBar"])],
    targets: [
        .target(name: "TuckBarCore"),
        .executableTarget(name: "TuckBar", dependencies: ["TuckBarCore"]),
        .testTarget(name: "TuckBarCoreTests", dependencies: ["TuckBarCore"])
    ]
)
