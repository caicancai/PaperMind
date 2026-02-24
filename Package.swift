// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PaperMind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PaperMind", targets: ["PaperMind"])
    ],
    targets: [
        .executableTarget(
            name: "PaperMind"
        )
    ]
)
