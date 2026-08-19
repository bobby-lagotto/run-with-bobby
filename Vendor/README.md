# Vendored MLX packages

`mlx-swift-lm` is vendored at tag **2.31.3** so we can point it at PrismML’s `mlx-swift` fork without an SPM identity conflict. 2.31.3 registers `qwen3_5`, required to load Bonsai 27B (Qwen3.5 hybrid / VLM config).

- Upstream: https://github.com/ml-explore/mlx-swift-lm (tag `2.31.3`)
- Patch: `Package.swift` depends on `https://github.com/PrismML-Eng/mlx-swift` branch `v0.31.3_prism` instead of `ml-explore/mlx-swift`
- Why: 1-bit Bonsai models need PrismML’s Metal kernels ([mlx#3161](https://github.com/ml-explore/mlx/pull/3161) not merged). Ternary 2-bit and Qwen 4-bit keep working on this fork.

When upstream MLX ships 1-bit affine quantization, drop this vendor copy and restore `ml-explore/mlx-swift-lm`.
