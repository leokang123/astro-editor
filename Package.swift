// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AstroPaperEditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AstroPaperEditor", targets: ["AstroPaperEditor"])
    ],
    targets: [
        .executableTarget(
            name: "AstroPaperEditor",
            path: "Sources/AstroPaperEditor"
        )
    ]
)
