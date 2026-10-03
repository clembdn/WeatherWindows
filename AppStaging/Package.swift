// swift-tools-version: 6.2
// Staging package: lets CI compile and test the app sources before the Xcode project exists.
// Its settings mirror a new Xcode 26 app target. Removed once the files move into the project.
import PackageDescription

let appSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances")
]

let package = Package(
    name: "AppStaging",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "WeatherWindow", targets: ["WeatherWindow"])
    ],
    dependencies: [
        .package(path: "../WeatherWindowKit")
    ],
    targets: [
        .target(
            name: "WeatherWindow",
            dependencies: [.product(name: "WeatherWindowKit", package: "WeatherWindowKit")],
            path: "WeatherWindow",
            resources: [.process("Resources")],
            swiftSettings: appSettings
        ),
        .testTarget(
            name: "WeatherWindowTests",
            dependencies: ["WeatherWindow"],
            path: "WeatherWindowTests",
            swiftSettings: appSettings
        )
    ]
)
