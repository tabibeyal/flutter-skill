// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FlutterSkill",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "FlutterSkill",
            targets: ["FlutterSkill"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FlutterSkill",
            dependencies: [],
            path: "Sources/FlutterSkill"
        ),
    ]
)
