// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GridBaseUIKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "GridBaseUIKit",
            targets: ["GridBaseUIKit"]
        )
    ],
    targets: [
        .target(
            name: "GridBaseUIKit",
            resources: [
                // Bundled GridBase fonts (JetBrains Mono / General Sans) if
                // present. Declaring a resource also guarantees `Bundle.module`
                // exists for GridFont's graceful registration / fallback.
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "GridBaseUIKitTests",
            dependencies: ["GridBaseUIKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
