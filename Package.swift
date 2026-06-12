// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CheckLinePrototype",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CheckLinePrototype",
            targets: ["CheckLinePrototype"]
        ),
        .executable(
            name: "CheckLinePrototypeRunner",
            targets: ["CheckLinePrototypeRunner"]
        ),
    ],
    targets: [
        .target(
            name: "CheckLinePrototype",
            path: "Sources/CheckLinePrototype",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "CheckLinePrototypeRunner",
            dependencies: ["CheckLinePrototype"],
            path: "Sources/CheckLinePrototypeRunner"
        ),
    ]
)
