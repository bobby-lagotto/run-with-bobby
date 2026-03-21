// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RunWithBobby",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RunWithBobby",
            targets: ["RunWithBobby"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.16.0"),
    ],
    targets: [
        .target(
            name: "RunWithBobby",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
            ]),
    ]
)