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
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")
    ],
    targets: [
        .executableTarget(
            name: "AstroPaperEditor",
            dependencies: ["Yams"],
            path: "Sources/AstroPaperEditor"
        ),
        .testTarget(name: "AstroPaperEditorTests", dependencies: ["AstroPaperEditor", "Yams"])
    ]
)
