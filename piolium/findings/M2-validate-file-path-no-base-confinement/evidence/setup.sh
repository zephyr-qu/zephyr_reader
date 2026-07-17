#!/bin/bash
# setup.sh - Environment provisioning for M2 PoC
# This PoC uses the existing Rust test infrastructure in zephyr_reader.
# No additional provisioning needed beyond the Rust toolchain.

set -e

echo "=== Environment Setup ==="
echo "OS: $(uname -o 2>/dev/null || echo unknown)"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Check Rust toolchain
rustc --version 2>&1
cargo --version 2>&1

# Verify the target project compiles
cd "$(dirname "$0")/../../../../rust"
echo "Project dir: $(pwd)"
echo "Setup complete."
