// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SiteIconKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15),
        .tvOS(.v15),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SiteIconKit",
            targets: ["SiteIconKit"]
        ),
    ],
    targets: [
        .target(
            name: "SiteIconKit",
            dependencies: [],
            path: "Sources/SiteIconKit"
        ),
        .testTarget(
            name: "SiteIconKitTests",
            dependencies: ["SiteIconKit"],
            path: "Tests/SiteIconKitTests"
        ),
    ]
)