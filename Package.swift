// swift-tools-version: 6.0

import PackageDescription

let iosStamp: [LinkerSetting] = [
    .unsafeFlags(
        ["-Xlinker", "-platform_version", "-Xlinker", "ios", "-Xlinker", "17.0", "-Xlinker", "26.2"],
        .when(platforms: [.iOS])
    )
]

let package = Package(
    name: "Datashard",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "Datashard", targets: ["Datashard"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Datashard",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            resources: [
                .copy("Resources"),
            ],
            linkerSettings: iosStamp
        ),
    ]
)
