// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GyroSteer",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "GyroSteerShared",
            targets: ["GyroSteerShared"]
        ),
        .library(
            name: "GyroSteerMacCore",
            targets: ["GyroSteerMacCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GyroSteerShared",
            path: "Shared"
        ),
        .target(
            name: "GyroSteerMacCore",
            dependencies: ["GyroSteerShared"],
            path: "GyroSteer-Mac",
            exclude: ["Resources", "App/GyroSteerMacApp.swift"]
        ),
        .testTarget(
            name: "GyroSteerSharedTests",
            dependencies: ["GyroSteerShared"],
            path: "Tests/SharedTests"
        ),
        .testTarget(
            name: "GyroSteerMacTests",
            dependencies: ["GyroSteerMacCore", "GyroSteerShared"],
            path: "Tests/MacTests"
        )
    ]
)
