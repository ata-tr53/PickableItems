// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PickableItems",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "PickableItems",
            targets: ["PickableItems"]
        ),
    ],
    targets: [
        .target(
            name: "PickableItems",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "PickableItemsTests",
            dependencies: ["PickableItems"]
        ),
    ]
)
