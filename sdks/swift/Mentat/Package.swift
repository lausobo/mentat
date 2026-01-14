// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Mentat",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Mentat",
            targets: ["Mentat"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MentatFFI",
            path: "External-Dependencies/MentatFFI.xcframework"
        ),
        .target(
            name: "MentatStore",
            path: "MentatStore",
            publicHeadersPath: "."
        ),
        .target(
            name: "Mentat",
            dependencies: ["MentatStore", "MentatFFI"],
            path: "Mentat",
            exclude: [
                "Info.plist",
                "Mentat.h",
                "store.h"
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedLibrary("resolv")
            ]
        ),
        .testTarget(
            name: "MentatTests",
            dependencies: ["Mentat"],
            path: "MentatTests",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .copy("fixtures")
            ]
        )
    ]
)
