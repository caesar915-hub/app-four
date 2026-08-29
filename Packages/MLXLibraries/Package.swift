// swift-tools-version: 5.9
// Vendored subset of mlx-swift-examples (upstream 2.29.1 + local constraint
// relaxation for swift-transformers) — only the LLM libraries the app links.
// Upstream `main` no longer ships MLXLLM/MLXLMCommon (moved to mlx-swift-lm),
// and tag 2.29.1 pins swift-transformers < 1.1, so we vendor the exact
// sources the pipeline is verified against.

import PackageDescription

let package = Package(
    name: "MLXLibraries",
    platforms: [.macOS(.v14), .iOS(.v16)],
    products: [
        .library(name: "MLXLLM", targets: ["MLXLLM"]),
        .library(name: "MLXLMCommon", targets: ["MLXLMCommon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.29.1")),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "MLXLLM",
            dependencies: [
                "MLXLMCommon",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Libraries/MLXLLM",
            exclude: ["README.md"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "MLXLMCommon",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Libraries/MLXLMCommon",
            exclude: ["README.md"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
