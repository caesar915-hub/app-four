// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquirlSignals",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "SquirlSignals", targets: ["SquirlSignals"]),
    ],
    targets: [
        .target(name: "SquirlSignals"),
    ],
    swiftLanguageModes: [.v5]
)
