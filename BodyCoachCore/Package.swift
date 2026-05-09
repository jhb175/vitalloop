// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BodyCoachCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BodyCoachCore",
            targets: ["BodyCoachCore"]
        ),
    ],
    targets: [
        .target(name: "BodyCoachCore"),
        .testTarget(
            name: "BodyCoachCoreTests",
            dependencies: ["BodyCoachCore"]
        ),
    ]
)
