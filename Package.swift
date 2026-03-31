// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunWithBobby",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.29.1"),
    ],
    targets: [
        .target(
            name: "RunWithBobby",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ],
            path: "RunWithBobby"),
    ]
)
