// swift-tools-version: 6.0
import PackageDescription

// Shared ActivityKit contract between the app target (produces/updates/ends the
// Live Activity) and the SquirlWidgets extension (renders it). Kept as a local
// package — not a synchronized-folder file — so one type compiles into both
// targets without per-file target-membership exceptions (research D2).
let package = Package(
    name: "SquirlLiveActivity",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "SquirlLiveActivity", targets: ["SquirlLiveActivity"])
    ],
    targets: [
        .target(name: "SquirlLiveActivity")
    ]
)
