// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkoutTimer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .executable(name: "WorkoutTimer", targets: ["WorkoutTimer"]),
    ],
    targets: [
        .target(name: "WorkoutCore"),
        .executableTarget(name: "WorkoutTimer", dependencies: ["WorkoutCore"]),
        .testTarget(name: "WorkoutCoreTests", dependencies: ["WorkoutCore"]),
    ]
)
