// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WhisperCLI",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "WhisperCLI",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        )
    ]
)
