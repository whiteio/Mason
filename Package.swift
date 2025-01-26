// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "mason",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "mason",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "MasonTests",
            dependencies: ["mason"]
        ),
    ]
)
