// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquirlDesignSystem",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "SquirlDesignSystem", targets: ["SquirlDesignSystem"]),
    ],
    dependencies: [
        .package(path: "../SquirlSignals"),
    ],
    targets: [
        .target(
            name: "SquirlDesignSystem",
            dependencies: ["SquirlSignals"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
