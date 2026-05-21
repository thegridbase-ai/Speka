// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpekaUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SpekaUI",
            targets: ["SpekaUI"]
        )
    ],
    targets: [
        .target(
            name: "SpekaUI",
            resources: [
                // Bundled Fredoka (OFL) display font + the staged Pip mascot
                // renders. Declaring resources also guarantees `Bundle.module`
                // exists for SpekaFont's graceful registration / fallback and
                // SpekaMascot's image loading.
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SpekaUITests",
            dependencies: ["SpekaUI"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
