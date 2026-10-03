// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeatherWindowKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "WeatherWindowKit",
            targets: ["WeatherWindowCore", "ForecastKit", "SolverKit", "NowcastKit"]
        )
    ],
    targets: [
        .systemLibrary(name: "CZlib", providers: [.apt(["zlib1g-dev"])]),
        .target(name: "WeatherWindowCore"),
        .target(name: "ForecastKit", dependencies: ["WeatherWindowCore"]),
        .target(name: "SolverKit", dependencies: ["WeatherWindowCore"]),
        .target(
            name: "NowcastKit",
            dependencies: ["WeatherWindowCore", "CZlib"],
            resources: [.copy("Resources/rainviewer_colors.csv")]
        ),
        .testTarget(name: "WeatherWindowCoreTests", dependencies: ["WeatherWindowCore"]),
        .testTarget(name: "SolverKitTests", dependencies: ["SolverKit"]),
        .testTarget(
            name: "ForecastKitTests",
            dependencies: ["ForecastKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "NowcastKitTests",
            dependencies: ["NowcastKit", "CZlib"],
            resources: [.copy("Fixtures")]
        )
    ]
)
