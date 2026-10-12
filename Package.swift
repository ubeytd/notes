// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Notes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Notes",
            resources: [.copy("Web")]
        )
    ]
)
