// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "NvidiaBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NvidiaBar", targets: ["NvidiaBar"])
    ],
    targets: [
        .executableTarget(
            name: "NvidiaBar",
            path: "Sources/NvidiaBar"
        ),
        .testTarget(
            name: "NvidiaBarTests",
            dependencies: ["NvidiaBar"],
            path: "Tests/NvidiaBarTests"
        )
    ]
)
