#!/bin/bash
# Verify local-catalog HuggingFace IDs exist and match expected MLX architectures.
set -euo pipefail

expect_type() {
  local id="$1"
  local expected="$2"
  local actual
  actual=$(curl -fsSL --max-time 30 "https://huggingface.co/${id}/raw/main/config.json" \
    | python3 -c "import json,sys; print(json.load(sys.stdin).get('model_type',''))")
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL $id: model_type=$actual expected=$expected" >&2
    exit 1
  fi
  echo "OK   $id ($actual)"
}

expect_type "mlx-community/Qwen2.5-0.5B-Instruct-4bit" "qwen2"
expect_type "mlx-community/Qwen2.5-1.5B-Instruct-4bit" "qwen2"
expect_type "mlx-community/Qwen2.5-3B-Instruct-4bit" "qwen2"
expect_type "prism-ml/Ternary-Bonsai-4B-mlx-2bit" "qwen3"
expect_type "prism-ml/Bonsai-8B-mlx-1bit" "qwen3"
expect_type "prism-ml/Bonsai-27B-mlx-1bit" "qwen3_5"

echo "Catalog HuggingFace check passed."
