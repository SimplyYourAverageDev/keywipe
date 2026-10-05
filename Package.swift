// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Keywipe",
    platforms: [.macOS(.v27)],
    targets: [
        .executableTarget(name: "Keywipe")
    ],
    swiftLanguageModes: [.v6]
)
