// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MARS",
    platforms: [
        .iOS(.v13) // Seleziona la piattaforma appropriata
    ],
    products: [
        .library(
            name: "MARS",
            targets: ["MARS"]),
    ],
    dependencies: [
        // Aggiungi il pacchetto swift-numerics
        .package(url: "https://github.com/apple/swift-numerics.git", .upToNextMajor(from: "1.0.2")),
    ],
    targets: [
        .target(
            name: "MARS",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics")
            ]),
        .testTarget(
            name: "MARSTests",
            dependencies: ["MARS"]),
    ]
)
