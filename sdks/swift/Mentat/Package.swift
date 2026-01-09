// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Mentat",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
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
