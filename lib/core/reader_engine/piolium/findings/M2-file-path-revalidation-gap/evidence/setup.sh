#!/bin/bash
# Environment setup for M2 PoC
# This proves the vulnerability by building the Rust library
# and running the test that demonstrates the path revalidation gap.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$SCRIPT_DIR/../../../rust"

echo "[setup] Changing to rust project directory: $RUST_DIR"
cd "$RUST_DIR"

echo "[setup] Building Rust library..."
cargo build --lib 2>&1

echo "[setup] Build complete."
echo "[setup] Run PoC with: cargo test --test poc_file_path_revalidation -- --nocapture"
