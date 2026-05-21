// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VocabularyKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VocabularyKit",
            targets: ["VocabularyKit"]
        )
    ],
    targets: [
        .target(
            name: "VocabularyKit",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "VocabularyKitTests",
            dependencies: ["VocabularyKit"],
            resources: [
                .process("Resources/words_a1.json")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
