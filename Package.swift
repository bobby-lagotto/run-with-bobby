// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunWithBobby",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(path: "Vendor/mlx-swift-lm"),
    ],
    targets: [
        .target(
            name: "RunWithBobby",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "RunWithBobby"),
    ]
)
