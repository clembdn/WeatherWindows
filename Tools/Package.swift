// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherWindowTools",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../WeatherWindowKit")
    ],
    targets: [
        .target(
            name: "ToolsCore",
            dependencies: [.product(name: "WeatherWindowKit", package: "WeatherWindowKit")]
        ),
        .executableTarget(name: "ww", dependencies: ["ToolsCore"]),
        .testTarget(name: "ToolsCoreTests", dependencies: ["ToolsCore"])
    ]
)
